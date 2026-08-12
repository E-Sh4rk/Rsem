open Mlsem.Common
module MVariable = Mlsem.Lang.MVariable
open Lang
open Tree_sitter_r
open R_types
module System = Mlsem.System
open Mlsem.Types

(* let () =
  Tree_sitter_run.Main.run
    ~lang:"r"
    ~parse_source_file:Parse.parse_source_file
    ~parse_input_tree:Parse.parse_input_tree
    ~dump_tree:Boilerplate.dump_tree
    ~dump_extras:Boilerplate.dump_extras *)

(* PARAMETERS *)
let record = ref false
let input_files = ref []
let gradual = ref false
(* ========== *)

module StrMap = Map.Make(String)

let refresh_vars kind gty =
  let drop1 str = String.sub str 1 (String.length str - 1) in
  let vars = GTy.fv gty in
  let s1 = MVarSet.elements1 vars
  |> List.map (fun tv -> tv, TVar.mk kind (Some (Sstt.Var.name tv |> drop1)) |> TVar.typ) in
  let s2 = MVarSet.elements2 vars
  |> List.map (fun rv -> rv, RVar.mk kind (Some (Sstt.RowVar.name rv |> drop1)) |> Row.id_for) in
  let s = Subst.of_list s1 s2 in
  GTy.substitute s gty
let is_arrow_sig ty = Ty.leq ty Arrow.any && not (Ty.is_empty ty)
let sigs_of_ty gty =
  let new_id = TVar.mk KInfer None |> TVar.typ in
  let fun_sig = ref false in
  let reidentify (a,b) = Rstt.Arg.reidentify ~id:new_id a, b in
  let reidentify ps = List.map reidentify ps in
  let reidentify ty =
    if is_arrow_sig ty then
      let dnf = Arrow.dnf ty |> List.map reidentify in
      fun_sig := true ;
      Arrow.of_dnf dnf
    else ty
  in
  let reidentify { Rstt.Attr.content ; classes ; attrs } =
    let content = reidentify content in
    {Rstt.Attr.content ; classes ; attrs}
  in
  let reidentify (ps, ns) = (List.map reidentify ps, ns) in
  let reidentify_attr ty =
    Rstt.Attr.destruct ty |> List.map reidentify |> List.map Rstt.Attr.mk_line |> Ty.disj
  in
  (* The reidentification is performed on the leaves of the type: the top-level
     type variables are not part of the attribute encoding, and [Attr.destruct]
     would drop them. *)
  let reidentify ty =
    Sstt.Ty.def ty
    |> Sstt.Ty.VDescr.map (fun d ->
      Sstt.Ty.mk_descr d |> reidentify_attr |> Sstt.Ty.get_descr)
    |> Sstt.Ty.of_def
  in
  let gty = refresh_vars KNoInfer gty in
  let fsig = GTy.map reidentify gty in
  !fun_sig, fsig
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

let add_sig ctx str tye =
  let open R_types.Types in
  let open Mlsem_common in
  let benv, ty = Builder.resolve ctx.benv tye in
  let {Builder.Gradual.lb;ub} = ty |> Builder.build_gradual ctx.tidenv in
  let gty = GTy.mk_gradual lb ub in
  (* If [str] has been declared as a class-overload, restrict its first parameter
     to the dispatched class and register the result as a new overload of the
     generic (in addition to the signature of [str] itself). *)
  let generic, gty =
    match StrMap.find_opt str ctx.covl with
    | None -> None, gty
    | Some (vg, cls) -> Some vg, MetaEnv.class_overload_ty cls gty
  in
  let fun_sig,s = sigs_of_ty gty in
  let v,s =
    match StrMap.find_opt str ctx.idenv with
    | Some v when fun_sig && VarMap.mem v ctx.senv -> (* Overload *)
      v,s::(VarMap.find v ctx.senv)
    | Some _ when fun_sig -> (* Redefinition of function signature (shadowing) *)
      MVariable.create Immut (Some str), [s]
    | Some _ -> (* Redefinition of mutable variable signature (shadowing) *)
      if GTy.fv gty |> MixVarSet.is_empty |> not
      then failwith "Non-functional signatures cannot have type variables" ;
      MVariable.create (AnnotMut gty) (Some str), [s]
    | None when fun_sig -> (* First signature definition *)
      MVariable.create Immut (Some str), [s]
    | None -> (* First mutable definition *)
      if GTy.fv gty |> MixVarSet.is_empty |> not
      then failwith "Non-functional signatures cannot have type variables" ;
      MVariable.create (AnnotMut gty) (Some str), [s]
  in
  let idenv = StrMap.add str v ctx.idenv in
  (* Format.printf "Adding %s: @[%a@]@." str TyScheme.pp ty ; *)
  (* Format.printf "Adding %s: @[%a@]@." str Sstt.Printer.print_ty'
    (TyScheme.get ty |> snd |> GTy.ub) ; *)
  let tenv = MetaEnv.add_signature v gty ctx.tenv in
  let tenv =
    match generic with
    | None -> tenv
    | Some vg -> MetaEnv.add_signature vg gty tenv
  in
  let senv = VarMap.add v s ctx.senv in
  { ctx with benv ; idenv ; tenv ; senv }

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
   treated as a signature: its type variables are made rigid, and its arrows are
   reidentified so that their parameters can be matched against the arguments of
   a call. Contrarily to a top-level annotation, it may contain type variables:
   they are bound by the enclosing scope. *)
let add_local_sig ctx offset f x tye =
  let open R_types.Types in
  let benv, ty = Builder.resolve ctx.benv tye in
  let {Builder.Gradual.lb;ub} = ty |> Builder.build_gradual ctx.tidenv in
  let lty = GTy.mk_gradual lb ub |> sigs_of_ty |> snd in
  { ctx with benv ; lannots = ctx.lannots@[{ loffset=offset ; lfun=f ; lvar=x ; lty }] }

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


(* ===== COMMAND LINE ===== *)

let usage_msg = "rsem [-record] [-gradual] <file1> [<file2>] ..."
let anon_fun filename =
    input_files := filename::!input_files
let speclist =
    [
      ("-record", Arg.Set record, "Record tallying instances into a file") ;
      ("-gradual", Arg.Set gradual, "Give the dyn type to undefined functions")
    ]

let snf _ cs = cs |> List.filter_map Rstt.TyOp.normalize_subst
let main (ctx, fn) =
  let res = Parse.file fn in
  match res.program with
  | None -> ctx
  | Some prog ->
    (* Boilerplate.dump_extras res.extras ; *)
    let tree = Boilerplate.map_program () prog in
    let prog = Parser.of_parser tree in
    (* Format.printf "%a@.@." PAst.pp prog ; *)
    (* The annotations declared by the previous files precede everything here. *)
    let ctx = { ctx with lannots =
      ctx.lannots |> List.map (fun a -> { a with loffset = min_int }) } in
    let ctx = List.fold_left (treat_extra prog) ctx res.extras in
    List.fold_left treat_def ctx prog

let () =
  Printexc.record_backtrace true ;
  Mlsem_types.PrinterCfg.set_descr_printer Rstt.Pp.print_descr_ctx ;
  Mlsem_types.PrinterCfg.set_printer Rstt.Pp.print ;
  Mlsem_types.PrinterCfg.add_printer_param (Rstt.Pp.printer_params ()) ;
  Mlsem_system.Config.normalization_fun := Fun.id ;
  Mlsem_system.Config.subst_normalization_fun := snf ;
  Mlsem.Lang.Config.void_ty := Transform.typeof_const CNull ;
  (* System.Config.infer_overload := false ; *)

  Arg.parse speclist anon_fun usage_msg ;
  if !record then Recording.start_recording () ;

  let ctx, penv = ref initial_ctx, ref PEnv.empty in
  List.rev !input_files |> List.iter (fun fn ->
      Format.printf "@.@{<bold>===== Processing %s =====@}@." fn ;
      Recording.clear () ;
      let ctx', penv' = PEnv.sequential_handler !penv main (!ctx, fn) in
      ctx := ctx' ; penv := penv' ;
      if !record then Recording.save_to_file fn (Recording.tally_calls ())
  )
