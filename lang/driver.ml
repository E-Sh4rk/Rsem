(** Driver of the R type-checker.

    Everything the [rsem] executable does apart from reading the command line
    lives here, so that another orchestrator (TypR) can drive the checker
    without going through the CLI -- and, in particular, can hand over an
    already-parsed program instead of a file name (see [parse] / [process]). *)

open Mlsem.Common
module MVariable = Mlsem.Lang.MVariable
open Tree_sitter_r
open R_types
module System = Mlsem.System
open Mlsem.Types

(* When set, undefined functions get the [dyn] type instead of being
   reported as unbound. Set by the [-gradual] flag. *)
let gradual = ref false

(* How the details of a typing error are printed: with the types involved, or
   with a witness of the failure (a value of the given type that is not of the
   expected one). Set to [Witnesses] by the [-witnesses] flag. *)
let errors_style = ref System.Error.Types

(* The details of a typing error. The failure of an [Alt] encoding an
   application gets the description [Transform] registered for it. *)
let error_descr (err:System.Error.t) =
  match err.kind with
  | UntypeableEncoding ->
    begin match Transform.alt_error err.eid err.env with
    | Some d -> Some d
    | None -> System.Error.descr ~style:!errors_style err
    end
  | _ -> System.Error.descr ~style:!errors_style err

module StrMap = Map.Make(String)

(* The type variables written in a signature are universally quantified: they
   are made rigid, so that the definition it annotates must be polymorphic in
   them. The variables introduced for the identifier of a polymorphic argument
   are an exception: they must stay inferable, so that the argument of the
   signature can be matched with the one of the definition. *)
let rigidify gty =
  let drop1 str = String.sub str 1 (String.length str - 1) in
  let poly = Rstt.Arg.polymorphic_vars () in
  let vars = GTy.fv gty in
  let s1 = MVarSet.elements1 vars |> List.map (fun tv ->
    let tv' =
      if Sstt.VarSet.mem tv poly then TVar.mk KInfer None
      else TVar.mk KNoInfer (Some (Sstt.Var.name tv |> drop1))
    in tv, TVar.typ tv') in
  let s2 = MVarSet.elements2 vars
  |> List.map (fun rv -> rv, RVar.mk KNoInfer (Some (Sstt.RowVar.name rv |> drop1)) |> Row.id_for) in
  let s = Subst.of_list s1 s2 in
  GTy.substitute s gty
let extend_env mlast env =
  if !gradual then
    let fv = System.Ast.fv mlast in
    let dom = Env.domain env |> VarSet.of_list in
    let missing = VarSet.diff fv dom in
    missing |> VarSet.elements |> List.fold_left
      (fun env v -> Env.add v (TyScheme.mk_mono GTy.dyn) env) env
  else
    env

(* Declared type of a variable local to a top-level function (cf. the
   [#| fun/var : t] declarations). Contrarily to a top-level signature, which
   is visible in the whole file, such an annotation is attached to the first
   definition of [lfun] that follows it, [loffset] being its position. *)
type lannot = { loffset: int ; lfun: string ; lvar: string ; lty: GTy.t }

(* [covl] maps the name of the method of each declared class-overload (e.g.
   [print.myclass], or [base::print.data.frame] for one of a namespace, cf.
   [qualified]) to the name of its generic function and to the class it
   dispatches on. *)
type typing_ctx = { idenv: Variable.t StrMap.t ; tenv: MetaEnv.t ; senv: GTy.t list VarMap.t ;
                    covl: (string * string) StrMap.t ; lannots: lannot list ;
                    benv: Rstt.Builder.env ; tidenv: Ty.t Rstt.Builder.TIdMap.t }
let initial_ctx = { benv=Rstt.Builder.empty_env ; tidenv=Rstt.Builder.TIdMap.empty ;
                    idenv=StrMap.empty ; tenv=MetaEnv.initial ; senv=VarMap.empty ;
                    covl=StrMap.empty ; lannots=[] }

let infer ctx mlast =
  (* Format.printf "%a@.@." System.Ast.pp mlast ; *)
  let env = MetaEnv.env (System.Ast.fv mlast) ctx.tenv |> extend_env mlast in
  let renvs = System.Refinement.refinements env mlast in
  let anns = System.Reconstruction.infer
    ~direct_narrowing:true ~partition_narrowing:false env renvs mlast in
  let tvs, ty = System.Checker.typeof_def env anns mlast |> TyScheme.get in
  TyScheme.mk tvs (GTy.ub ty |> GTy.mk)

(* A top-level definition that cannot be generalized (value restriction) may
   still contain type variables that reconstruction left unconstrained ("weak"
   variables, e.g. the instance of a signature applied in the body of a closure
   that [local] returns). Nothing that comes later can constrain them, so they
   are instantiated: any instance is sound, typing being stable by substitution
   and the top-level environment closed, whereas generalizing them would not be.
   The variables of a single polarity get their extremal instance (as in
   [close_uninit]), the others [empty]. *)
let instantiate_weak ts =
  let tvs, gty = TyScheme.get ts in
  let gty = GTy.map (TVOp.bot_instance tvs) gty in
  let weak = MVarSet.diff (GTy.fv gty) tvs in
  let s1 = MVarSet.elements1 weak |> List.map (fun v -> v, Ty.empty) in
  let s2 = MVarSet.elements2 weak |> List.map (fun v -> v, Row.empty) in
  TyScheme.mk tvs (GTy.substitute (Subst.of_list s1 s2) gty)

(* What became of a variable [treat_def] typed, for an embedder (TypR) that
   wants it structured rather than printed. [Typed] carries the type the
   variable now has, also when it was checked against a signature;
   [Untypeable] the checker's error and the position it is about ([dummy]
   when it has none); [Failed] the message of a name [treat_def] hoists out of
   a statement, whose typing raised [Failure]. *)
type outcome =
  | Typed of TyScheme.t
  | Untypeable of System.Error.t * Position.t
  | Failed of string

let on_outcome : (Variable.t -> outcome -> unit) ref = ref (fun _ _ -> ())

let treat_ast ?(post=Fun.id) v ctx ast =
  let open Mlsem_system.Ast in
  try
    let ctx = match VarMap.find_opt v ctx.senv with
    | None (* Inference mode *) ->
      (* The coercions of the annotated local variables must be pushed too, so
         that they guide the reconstruction instead of only constraining the
         type inferred for their definition. *)
      let mlast = Transform.to_mlsem { env=ctx.tenv } ast
        |> push_coercions ~duplicate_arrows:true in
      (* Format.printf "%a@.@." System.Ast.pp mlast ; *)
      let ty = infer ctx mlast |> post |> instantiate_weak in
      { ctx with tenv=MetaEnv.set_from_tyscheme v ty ctx.tenv }
    | Some sigs (* Type checking mode *) ->
      let mlast = Transform.to_mlsem { env=ctx.tenv } ast in
      (* Format.printf "%a@.@." System.Ast.pp mlast ; *)
      let asts = sigs |> List.map (fun s -> 
        (Eid.refresh (fst mlast), TypeCoerce (mlast, s, CheckStatic)) |> push_coercions ~duplicate_arrows:true) in
      let _ = List.map (infer ctx) asts in
      { ctx with senv=VarMap.remove v ctx.senv } (* The signature has been verified, remove it *)
    in
    let ty = MetaEnv.get v ctx.tenv in
    Format.printf "%a:@? @[%a@]@.@." Variable.pp v TyScheme.pp_short ty ;
    !on_outcome v (Typed ty) ;
    ctx
  with System.Error.Untypeable (err) ->
    Format.printf "%a:@? Untypeable: %s@." Variable.pp v (System.Error.title err) ;
    let loc = Eid.loc err.eid in
    if loc <> Position.dummy then Format.printf "%s@." (Position.string_of_pos loc) ;
    error_descr err |> Option.iter (Format.printf "%s@.") ;
    Format.printf "@." ;
    !on_outcome v (Untypeable (err, loc)) ;
    { ctx with senv=VarMap.remove v ctx.senv } (* Do not keep a failed signature pending *)

(* Name of the variable a top-level definition binds, if any. It is the name
   under which the annotations of its local variables are registered. *)
let toplevel_name (_,e) =
  match e with
  | PAst.Binop (("<-"|"="), ((_, PAst.Id str), _))
  | PAst.Binop ("->", (_, (_, PAst.Id str))) -> Some str
  | _ -> None

(* Extracts from [ctx] the annotations that the definition of [name] ending at
   the offset [end_] claims: those declared before it, or inside its own body.
   They are removed from [ctx], so that a later definition shadowing [name] can
   declare its own annotations. *)
let claim_lannots ctx name end_ =
  match name with
  | None -> ctx, StrMap.empty
  | Some f ->
    let claimed, lannots = ctx.lannots
      |> List.partition (fun a -> String.equal a.lfun f && a.loffset < end_) in
    let annots = claimed |> List.fold_left (fun acc a ->
      if StrMap.mem a.lvar acc
      then failwith ("The local variable "^f^"/"^a.lvar^" has several type annotations.") ;
      StrMap.add a.lvar a.lty acc) StrMap.empty in
    { ctx with lannots }, annots

let dummy_var = Variable.create (Some "_")

let close_uninit ts =
  let tvs, gty = TyScheme.get ts in
  let gty = GTy.map (TVOp.bot_instance tvs) gty in
  TyScheme.mk (MVarSet.union tvs (GTy.fv gty)) gty

(* The names a top-level statement assigns from *inside* an expression, rather
   than as a definition of its own. A brace is not a scope in R, so
   [blk <- { u <- 1 ; u }] defines [u] just as much as [blk], and so do a
   top-level [if] or [for]. Such a name has to be mutable.

   A declared name is left out: it keeps the variable its declaration built,
   which is mutable already and carries the type the user wrote. A name that a
   previous statement defined is kept in, and the definition below shadows it,
   exactly as a second top-level definition of the same name would. *)
let hoisted_names ctx name past =
  let bvs = PAst.bv_e ~local_shadowed:(StrMap.mem "local" ctx.idenv) past in
  let bvs = match name with None -> bvs | Some n -> PAst.StrSet.remove n bvs in
  bvs |> PAst.StrSet.filter (fun str ->
    match StrMap.find_opt str ctx.idenv with
    | None -> true
    | Some v ->
      (match MVariable.kind v with MVariable.AnnotMut _ -> false | _ -> true)
      && not (VarMap.mem v ctx.senv))

let treat_def ctx past =
  let name = toplevel_name past in
  let end_ = (Position.end_of_position (fst past)).Lexing.pos_cnum in
  let ctx, annots = claim_lannots ctx name end_ in
  let hoisted = hoisted_names ctx name past in
  let ctx = PAst.StrSet.fold (fun str ctx ->
    { ctx with idenv =
        StrMap.add str (MVariable.create MVariable.Mut (Some str)) ctx.idenv })
    hoisted ctx in
  let (eid,ast) = PAst.transform
    { PAst.id = Scope.from_toplevel ctx.tenv ctx.idenv ; annots } past in
  (* Format.printf "%a@.@." Ast.pp_e (id,ast) ; *)
  let declared body =
    PAst.StrSet.fold (fun str acc ->
      match StrMap.find_opt str ctx.idenv with
      | None -> acc
      | Some v -> (Eid.unique (), Ast.Declare (v, acc))) hoisted body
  in
  (* The statement is what gives the hoisted names their types: each is read
     back by sequencing the statement with the name itself. *)
  let treat_hoisted body ctx =
    PAst.StrSet.fold (fun str ctx ->
      match StrMap.find_opt str ctx.idenv with
      | None -> ctx
      | Some v ->
        let read = Eid.unique (), Ast.Seq (body, (Eid.unique (), Ast.Id v)) in
        match treat_ast ~post:close_uninit v ctx (declared read) with
        | exception Failure msg ->
          (* A name introduced this way is a convenience, not something the file
           asked for, so failing to type one leaves it unbound rather than
           taking the whole run down with it. *)
          Format.printf "%s:@? %s@.@." str msg ;
          !on_outcome v (Failed msg) ;
          ctx
        | ctx ->
          if not (MetaEnv.mem v ctx.tenv) then ctx
          else
            let v' = MVariable.create Immut (Some str) in
            { ctx with idenv = StrMap.add str v' ctx.idenv ;
                       tenv = MetaEnv.set_from_tyscheme v' (MetaEnv.get v ctx.tenv) ctx.tenv })
      hoisted ctx
  in
  match ast with
  | VarAssign (v, e) ->
    (* If v is a fresh var (i.e. if it was not declared before), add it to the idenv *)
    let ctx =
      match Variable.get_name v with
      | Some str -> { ctx with idenv = StrMap.add str v ctx.idenv }
      | None -> ctx
    in
    treat_ast v ctx (declared e) |> treat_hoisted e
  | _ -> treat_ast dummy_var ctx (declared (eid, ast)) |> treat_hoisted (eid, ast)

(* Conversion of a type, as written in an annotation, to a gradual type. *)
let build_gty tidenv tye =
  let open R_types.Types in
  let {Builder.Gradual.lb;ub} = tye |> Builder.build_gradual tidenv in
  GTy.mk_gradual lb ub

(* Resolves the identifiers of the annotation [tye] and turns it into a
   signature, together with the types the definition it annotates must be
   checked against: one per arrow of a function signature (an intersection of
   arrows, each being checked separately), and none when the signature still
   contains label variables.
   If [cls] is set, [tye] annotates the overload of a generic function for the
   class [cls]: its first parameter is restricted to the values of that class. *)
let build_sig ctx cls tye =
  let open R_types.Types in
  match tye with
  | Sigs.AFun fsig ->
    let benv, fsig = FunSig.resolve ctx.benv fsig in
    let fsig = MetaEnv.mk_fsig (build_gty ctx.tidenv) fsig in
    let fsig = match cls with
      | None -> fsig
      | Some cls -> MetaEnv.class_overload_sig cls fsig in
    let chk =
      if MetaEnv.is_resolved fsig
      then MetaEnv.arrows fsig |> List.map (fun f -> MetaEnv.fsig_ty ~polymorphic:true f |> rigidify)
      else [] in
    { ctx with benv }, MetaEnv.SigFun fsig, chk
  | Sigs.ATy tye ->
    let benv, tye = Builder.resolve ctx.benv tye in
    let gty = build_gty ctx.tidenv tye in
    let gty = match cls with
      | None -> gty
      | Some cls -> MetaEnv.class_overload_ty cls gty in
    { ctx with benv }, MetaEnv.SigTy gty, [rigidify gty]

(* Name under which the class-overload [str] of the namespace [ns] is
   registered. A global name cannot contain [::], so it cannot clash with it. *)
let qualified ns str =
  match ns with
  | None -> str
  | Some ns -> ns^"::"^str

(* The variable the top-level name [str] refers to: its global definition, or
   else the one of the search path (cf. [MetaEnv.search]). *)
let lookup ctx str =
  match StrMap.find_opt str ctx.idenv with
  | Some v -> Some v
  | None -> MetaEnv.search str ctx.tenv

(* The generic a method of the namespace [ns] extends is looked up from that
   namespace: in the namespace itself, and then in the search path. As in R, the
   global definitions of the program play no part in it. *)
let lookup_from ctx ns str =
  match ns with
  | None -> lookup ctx str
  | Some ns ->
    match MetaEnv.ns_find ns str ctx.tenv with
    | Some v -> Some v
    | None -> MetaEnv.search str ctx.tenv

(* The variable of the generic [m] that the method of the namespace [ns] is
   registered in (cf. [lookup_from]). *)
let generic_of ctx ns m cls =
  match lookup_from ctx ns m with
  | Some vg -> vg
  | None ->
    failwith ("Cannot add the signature of the class-overload "^(qualified ns (m^"."^cls))^
      ": no generic function found (it must be declared before its overloads).")

(* Registers the signature [sign] of the method [str] of the namespace [ns] as
   an overload of its generic, if [str] has been declared as a class-overload. *)
let add_to_generic ctx ns str sign tenv =
  match StrMap.find_opt (qualified ns str) ctx.covl with
  | None -> tenv
  | Some (m, cls) -> MetaEnv.add_signature ~cls ~name:m (generic_of ctx ns m cls) sign tenv

let add_sig ctx str tye =
  let open Mlsem_common in
  (* If [str] has been declared as a class-overload, its first parameter is
     restricted to the dispatched class, and the result is registered as a new
     overload of the generic (in addition to the signature of [str] itself). *)
  let generic = StrMap.find_opt str ctx.covl in
  let ctx, sign, chk = build_sig ctx (Option.map snd generic) tye in
  let v,sigs =
    match sign with
    | MetaEnv.SigFun _ ->
      begin match StrMap.find_opt str ctx.idenv with
      | Some v when VarMap.mem v ctx.senv -> (* Overload *)
        v, chk@(VarMap.find v ctx.senv)
      (* First signature definition, or redefinition (shadowing) *)
      | _ -> MVariable.create Immut (Some str), chk
      end
    | MetaEnv.SigTy _ -> (* Definition (or redefinition) of a mutable variable *)
      let s = GTy.conj chk in
      if GTy.fv s |> MVarSet.is_empty |> not
      then failwith "Non-functional signatures cannot have type variables" ;
      MVariable.create (AnnotMut s) (Some str), [s]
  in
  let tenv = MetaEnv.add_signature ~name:str v sign ctx.tenv |> add_to_generic ctx None str sign in
  let idenv = StrMap.add str v ctx.idenv in
  let senv = VarMap.add v sigs ctx.senv in
  { ctx with idenv ; tenv ; senv }

let add_class ctx ns m cls =
  { ctx with tenv=MetaEnv.new_class_overload m cls ctx.tenv ;
             covl=StrMap.add (qualified ns (m^"."^cls)) (m, cls) ctx.covl }

let add_alias ctx str tye =
  let open R_types.Types in
  let benv, ty = Builder.resolve ctx.benv tye in
  let tid = Builder.TId.create () in
  let benv = { benv with tids=Builder.StrMap.add str tid benv.tids } in
  let ctx = { ctx with benv } in
  let ty = ty |> Builder.build ctx.tidenv in
  let ctx = { ctx with tidenv=Builder.TIdMap.add tid ty ctx.tidenv } in
  PEnv.register str ty ; ctx

(* Annotation of the variable [x] local to the top-level function [f]. It is
   treated as a signature: its type variables are made rigid, and the argument
   of a function signature is made polymorphic so that it can be matched against
   the parameters of the annotated definition. Contrarily to a top-level
   annotation, it may contain type variables: they are bound by the enclosing
   scope. *)
let add_local_sig ctx offset f x tye =
  let ctx, _, chk = build_sig ctx None tye in
  match chk with
  | _::_ ->
    let lty = GTy.conj chk in
    { ctx with lannots = ctx.lannots@[{ loffset=offset ; lfun=f ; lvar=x ; lty }] }
  | [] ->
    failwith ("The annotation of the local variable "^f^"/"^x^
      " cannot contain label variables.")

(* Annotation of the name [str] of the namespace [ns]. No definition of the
   file can be checked against it, since R code cannot assign [ns::str]: it is
   only registered, every signature of [ns::str] being one of its overloads.
   As for a global name, a declared class-overload is restricted to its class
   and also registered as an overload of its generic. *)
let add_ns_sig ctx ns str tye =
  let generic = StrMap.find_opt (qualified (Some ns) str) ctx.covl in
  let ctx, sign, chk = build_sig ctx (Option.map snd generic) tye in
  begin match sign, chk with
  | MetaEnv.SigTy _, [s] when GTy.fv s |> MVarSet.is_empty |> not ->
    failwith "Non-functional signatures cannot have type variables"
  | _ -> ()
  end ;
  let tenv = MetaEnv.ns_add_signature ns str sign ctx.tenv
    |> add_to_generic ctx (Some ns) str sign in
  { ctx with tenv }

(* Every declaration but a class-overload may build types that mention
   classes: the classes declared so far must be declared to rstt first. *)
let add_def ctx offset def =
  begin match def with Sigs.NewClass _ -> () | _ -> MetaEnv.declare_classes ctx.tenv end ;
  match def with
  | Sigs.Sig (str, tye) -> add_sig ctx str tye
  | Sigs.LocalSig (f, str, tye) -> add_local_sig ctx offset f str tye
  | Sigs.NsSig (ns, str, tye) -> add_ns_sig ctx ns str tye
  | Sigs.Alias (str, tye) -> add_alias ctx str tye
  | Sigs.NewClass (ns, m, cls) -> add_class ctx ns m cls

(* Name of the top-level definition the offset [offset] falls into, if any. *)
let enclosing_def prog offset =
  let contains past =
    let pos = fst past in
    (Position.start_of_position pos).Lexing.pos_cnum <= offset &&
    offset < (Position.end_of_position pos).Lexing.pos_cnum
  in
  match List.find_opt contains prog with
  | None -> None
  | Some past -> toplevel_name past

(* A [#|] comment written inside the definition of [f] declares the type of a
   variable local to [f]: there, a bare [#| var : t] is exactly the top-level
   [#| f/var : t]. Every other declaration is treated right away, as it is
   visible in the whole file whatever its position.

   The marker is [#|] rather than [##] so that it cannot be confused with an
   ordinary comment: [##] is a common way of writing prose in R sources, and
   every such line would otherwise be parsed as a declaration and rejected.

   An annotation can be written on several lines: a [#|] line whose text
   starts with more than one blank continues the annotation of the line just
   before it (whereas a declaration starts with a single blank, as in
   [#| name : t]), e.g.
     #| f : (x: dbl1) -> dbl1
     #|   && (x: chr1) -> chr1
   Its text is joined to the annotation, which keeps the offset of its first
   line. *)
let annotations extras =
  let is_continuation str =
    String.length str >= 2 &&
    match str.[0], str.[1] with
    | ' ', (' ' | '\t') | '\t', _ -> true
    | _ -> false
  in
  (* The annotations, in reverse order, each with its offset, the row of its
     last line and its text. *)
  extras |> List.fold_left (fun acc extra ->
    match extra with
    | `Comment (loc, (_, str)) when String.starts_with ~prefix:"#|" str ->
      let row = loc.Tree_sitter_run.Loc.start.row in
      let str = String.sub str 2 ((String.length str) - 2) in
      if is_continuation str then
        match acc with
        | (offset, row', str')::acc when row' = row - 1 ->
          (offset, row, str'^" "^String.trim str)::acc
        | _ ->
          failwith (Printf.sprintf
            "Line %i: this annotation continues no annotation on the line before it."
            (row + 1))
      else (Parser.start_offset_of_loc loc, row, str)::acc
    | _ -> acc
  ) [] |> List.rev |> List.map (fun (offset, _, str) -> offset, str)

let treat_annotation prog ctx (offset, str) =
  match enclosing_def prog offset, IO.parse_def str with
  | Some f, Sigs.Sig (x, tye) -> add_def ctx offset (Sigs.LocalSig (f, x, tye))
  | _, def -> add_def ctx offset def

(* ===== ENTRY POINTS ===== *)

(* Installs the rstt printers and the mlsem configuration the R type-checker
   expects. Must be called once, before any type is built or printed. *)
let setup () =
  Mlsem_types.PrinterCfg.set_descr_printer Rstt.Pp.print_descr_ctx ;
  Mlsem_types.PrinterCfg.set_printer Rstt.Pp.print ;
  Mlsem_types.PrinterCfg.set_printer_params [Rstt.Pp.printer_params ()] ;
  Mlsem_system.Config.reexplore_failed_domains := true ;
  Mlsem_system.Config.assimilate_vars := true ;
  Mlsem_system.Config.infer_overload := true ;
  Mlsem_system.Config.factorize_abstracts := false ;
  Mlsem_system.Config.var_simplification_fun := (fun ~is_lambda:_ _ _ -> Subst.identity) ;
  Mlsem_system.Config.normalization_fun := Fun.id ;
  Mlsem_system.Config.subst_normalization_fun :=
    (fun _ cs -> cs |> List.filter_map Rstt.TyOp.normalize_subst) ;
  Mlsem.Lang.Config.void_ty := Transform.typeof_const CNull

(* Parses [fn] into the R surface AST, together with the comment extras that
   carry the [#|] type annotations. [None] if the file could not be parsed. *)
let parse fn =
  let res = Parse.file fn in
  match res.program with
  | None -> None
  | Some prog ->
    let tree = Boilerplate.map_program () prog in
    Some (Parser.of_parser tree, res.extras)

(* Declares the class-overloads of an already-parsed program, and nothing
   else. As they determine the class hierarchy and the restrictions of the
   signatures, they must be known before any signature is treated: when
   several programs are checked together, this is called on all of them before
   [process] is called on the first. Declaring them again in [process] has then
   no effect. An annotation that cannot be parsed is skipped here, [process]
   reports it. *)
let declare_overloads ctx (_, extras) =
  let annots = try annotations extras with Failure _ -> [] in
  annots |> List.fold_left (fun ctx (_, str) ->
    match IO.parse_def str with
    | Sigs.NewClass (ns, m, cls) -> add_class ctx ns m cls
    | _ | exception _ -> ctx
  ) ctx

(* Type-checks an already-parsed program. This is the half of [main] that does
   not touch the file system, so a caller that has parsed the file itself (or
   rewritten the AST beforehand) does not have to parse it a second time. *)
let process ctx (prog, extras) =
  (* The annotations declared by the previous files precede everything here. *)
  let ctx = { ctx with lannots =
    ctx.lannots |> List.map (fun a -> { a with loffset = min_int }) } in
  let ctx = List.fold_left (treat_annotation prog) ctx (annotations extras) in
  MetaEnv.declare_classes ctx.tenv ;
  List.fold_left treat_def ctx prog

let main (ctx, fn) =
  match parse fn with
  | None -> ctx
  | Some parsed -> process ctx parsed

(* ===== ACCESS TO THE TYPING CONTEXT ===== *)

(* The type inferred (or declared) for the top-level name [str], if any. *)
let find ctx str =
  match lookup ctx str with
  | Some v when MetaEnv.mem v ctx.tenv -> Some (MetaEnv.get v ctx.tenv)
  | _ -> None

(* Binds the top-level name [str] to the type [gty], as if it had been declared
   with a signature. Used by TypR to inject the types inferred on the native
   side for the symbols an R file reaches through [.Call] and friends. *)
let bind ctx str gty =
  let v = MVariable.create Immut (Some str) in
  { ctx with idenv = StrMap.add str v ctx.idenv ;
             tenv = MetaEnv.set_from_tyscheme v (TyScheme.mk_poly gty) ctx.tenv }
