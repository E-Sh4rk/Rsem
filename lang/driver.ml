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
   [## fun::var : t] declarations). Contrarily to a top-level signature, which
   is visible in the whole file, such an annotation is attached to the first
   definition of [lfun] that follows it, [loffset] being its position. *)
type lannot = { loffset: int ; lfun: string ; lvar: string ; lty: GTy.t }

(* [covl] maps the name of each declared class-overload (e.g. [print.myclass])
   to its generic function and to the class it dispatches on. *)
type typing_ctx = { idenv: Variable.t StrMap.t ; tenv: MetaEnv.t ; senv: GTy.t list VarMap.t ;
                    covl: (Variable.t * string) StrMap.t ; lannots: lannot list ;
                    benv: Rstt.Builder.env ; tidenv: Ty.t Rstt.Builder.TIdMap.t }
let initial_ctx = { benv=Rstt.Builder.empty_env ; tidenv=Rstt.Builder.TIdMap.empty ;
                    idenv=StrMap.empty ; tenv=MetaEnv.initial ; senv=VarMap.empty ;
                    covl=StrMap.empty ; lannots=[] }

let infer ctx mlast =
  (* Format.printf "%a@.@." System.Ast.pp mlast ; *)
  let env = MetaEnv.env ctx.tenv |> extend_env mlast in
  let renvs = System.Refinement.refinements env mlast in
  let anns = System.Reconstruction.infer
    ~direct_narrowing:true ~partition_narrowing:false env renvs mlast in
  let tvs, ty = System.Checker.typeof_def env anns mlast |> TyScheme.get in
  TyScheme.mk tvs (GTy.ub ty |> GTy.mk)

let treat_ast v ctx ast =
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
      let ty = infer ctx mlast in
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
    ctx
  with System.Checker.Untypeable (err) ->
    Format.printf "%a:@? Untypeable: %s@." Variable.pp v err.title ;
    let loc = Eid.loc err.eid in
    if loc <> Position.dummy then Format.printf "%s@." (Position.string_of_pos loc) ;
    err.descr |> Option.iter (Format.printf "%s@.") ;
    Format.printf "@." ; ctx

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
      then failwith ("The local variable "^f^"::"^a.lvar^" has several type annotations.") ;
      StrMap.add a.lvar a.lty acc) StrMap.empty in
    { ctx with lannots }, annots

let dummy_var = Variable.create (Some "_")
let treat_def ctx past =
  let name = toplevel_name past in
  let end_ = (Position.end_of_position (fst past)).Lexing.pos_cnum in
  let ctx, annots = claim_lannots ctx name end_ in
  let (eid,ast) = PAst.transform
    { PAst.id = Scope.from_toplevel (MetaEnv.env ctx.tenv) ctx.idenv ; annots } past in
  (* Format.printf "%a@.@." Ast.pp_e (id,ast) ; *)
  match ast with
  | VarAssign (v, e) ->
    (* If v is a fresh var (i.e. if it was not declared before), add it to the idenv *)
    let ctx =
      match Variable.get_name v with
      | Some str -> { ctx with idenv = StrMap.add str v ctx.idenv }
      | None -> ctx
    in
    treat_ast v ctx e
  | _ -> treat_ast dummy_var ctx (eid, ast)

(* Conversion of a type, as written in an annotation, to a gradual type. *)
let build_gty tidenv tye =
  let open R_types.Types in
  let {Builder.Gradual.lb;ub} = tye |> Builder.build_gradual tidenv in
  GTy.mk_gradual lb ub

(* Resolves the identifiers of the annotation [tye] and turns it into a
   signature, together with the type the definition it annotates must be checked
   against (there is none when the signature still contains label variables).
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
      then Some (MetaEnv.fsig_ty ~polymorphic:true fsig |> rigidify)
      else None in
    { ctx with benv }, MetaEnv.SigFun fsig, chk
  | Sigs.ATy tye ->
    let benv, tye = Builder.resolve ctx.benv tye in
    let gty = build_gty ctx.tidenv tye in
    let gty = match cls with
      | None -> gty
      | Some cls -> MetaEnv.class_overload_ty cls gty in
    { ctx with benv }, MetaEnv.SigTy gty, Some (rigidify gty)

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
        v, (Option.to_list chk)@(VarMap.find v ctx.senv)
      (* First signature definition, or redefinition (shadowing) *)
      | _ -> MVariable.create Immut (Some str), Option.to_list chk
      end
    | MetaEnv.SigTy _ -> (* Definition (or redefinition) of a mutable variable *)
      let s = Option.get chk in
      if GTy.fv s |> MVarSet.is_empty |> not
      then failwith "Non-functional signatures cannot have type variables" ;
      MVariable.create (AnnotMut s) (Some str), [s]
  in
  let idenv = StrMap.add str v ctx.idenv in
  let tenv = MetaEnv.add_signature v sign ctx.tenv in
  let tenv =
    match generic with
    | None -> tenv
    | Some (vg, _) -> MetaEnv.add_signature vg sign tenv
  in
  let senv = VarMap.add v sigs ctx.senv in
  { ctx with idenv ; tenv ; senv }

(* Splits [str] into a generic function name and a class name, on each of its
   dots, longest generic first (e.g. [print.data.frame] yields
   [("print.data","frame") ; ("print","data.frame")]). *)
let class_overload_splits str =
  let n = String.length str in
  List.init n Fun.id
  |> List.filter (fun i -> i > 0 && i < n-1 && str.[i] = '.')
  |> List.rev_map (fun i -> String.sub str 0 i, String.sub str (i+1) (n-i-1))

let add_class ctx str =
  let generic = class_overload_splits str
    |> List.find_opt (fun (g,_) -> StrMap.mem g ctx.idenv) in
  match generic with
  | None ->
    failwith ("Cannot declare the class-overload "^str^
      ": no generic function found (it must be declared before its overloads).")
  | Some (g, cls) ->
    let vg = StrMap.find g ctx.idenv in
    { ctx with tenv=MetaEnv.new_class_overload vg cls ctx.tenv ;
               covl=StrMap.add str (vg, cls) ctx.covl }

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
  | Some lty ->
    { ctx with lannots = ctx.lannots@[{ loffset=offset ; lfun=f ; lvar=x ; lty }] }
  | None ->
    failwith ("The annotation of the local variable "^f^"::"^x^
      " cannot contain label variables.")

let add_def ctx offset def =
  match def with
  | Sigs.Sig (str, tye) -> add_sig ctx str tye
  | Sigs.LocalSig (f, str, tye) -> add_local_sig ctx offset f str tye
  | Sigs.Alias (str, tye) -> add_alias ctx str tye
  | Sigs.NewClass str -> add_class ctx str

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

(* A [##] comment written inside the definition of [f] declares the type of a
   variable local to [f]: there, a bare [## var : t] is exactly the top-level
   [## f::var : t]. Every other declaration is treated right away, as it is
   visible in the whole file whatever its position. *)
let treat_extra prog ctx extra =
  match extra with
  | `Comment (loc, (_, str)) ->
    if String.starts_with ~prefix:"##" str then
      let offset = Parser.start_offset_of_loc loc in
      let str = String.sub str 2 ((String.length str) - 2) in
      match enclosing_def prog offset, IO.parse_def str with
      | Some f, Sigs.Sig (x, tye) -> add_local_sig ctx offset f x tye
      | _, def -> add_def ctx offset def
    else ctx

(* ===== ENTRY POINTS ===== *)

(* Installs the rstt printers and the mlsem configuration the R type-checker
   expects. Must be called once, before any type is built or printed. *)
let setup () =
  Mlsem_types.PrinterCfg.set_descr_printer Rstt.Pp.print_descr_ctx ;
  Mlsem_types.PrinterCfg.set_printer Rstt.Pp.print ;
  Mlsem_types.PrinterCfg.add_printer_param (Rstt.Pp.printer_params ()) ;
  Mlsem_system.Config.normalization_fun := Fun.id ;
  Mlsem_system.Config.subst_normalization_fun :=
    (fun _ cs -> cs |> List.filter_map Rstt.TyOp.normalize_subst) ;
  Mlsem.Lang.Config.void_ty := Transform.typeof_const CNull

(* Parses [fn] into the R surface AST, together with the comment extras that
   carry the [##] type annotations. [None] if the file could not be parsed. *)
let parse fn =
  let res = Parse.file fn in
  match res.program with
  | None -> None
  | Some prog ->
    let tree = Boilerplate.map_program () prog in
    Some (Parser.of_parser tree, res.extras)

(* Type-checks an already-parsed program. This is the half of [main] that does
   not touch the file system, so a caller that has parsed the file itself (or
   rewritten the AST beforehand) does not have to parse it a second time. *)
let process ctx (prog, extras) =
  (* The annotations declared by the previous files precede everything here. *)
  let ctx = { ctx with lannots =
    ctx.lannots |> List.map (fun a -> { a with loffset = min_int }) } in
  let ctx = List.fold_left (treat_extra prog) ctx extras in
  List.fold_left treat_def ctx prog

let main (ctx, fn) =
  match parse fn with
  | None -> ctx
  | Some parsed -> process ctx parsed

(* ===== ACCESS TO THE TYPING CONTEXT ===== *)

(* The type inferred (or declared) for the top-level name [str], if any. *)
let find ctx str =
  match StrMap.find_opt str ctx.idenv with
  | Some v when MetaEnv.mem v ctx.tenv -> Some (MetaEnv.get v ctx.tenv)
  | _ -> None

(* Binds the top-level name [str] to the type [gty], as if it had been declared
   with a signature. Used by TypR to inject the types inferred on the native
   side for the symbols an R file reaches through [.Call] and friends. *)
let bind ctx str gty =
  let v = MVariable.create Immut (Some str) in
  { ctx with idenv = StrMap.add str v ctx.idenv ;
             tenv = MetaEnv.set_from_tyscheme v (TyScheme.mk_poly gty) ctx.tenv }
