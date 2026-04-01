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

module StrMap = Map.Make(String)

let simplify_tl ty = ty |> TyScheme.bot_instance |> TyScheme.norm_and_simpl
let merge_tl tys =
  let tscap t1 t2 =
    let (tvs1, t1), (tvs2, t2) = TyScheme.get t1, TyScheme.get t2 in
    TyScheme.mk (MVarSet.union tvs1 tvs2) (GTy.cap t1 t2)
  in
  List.fold_left tscap (TyScheme.mk_mono GTy.any) tys |> simplify_tl
let refresh_vars kind ty =
  let drop1 str = String.sub str 1 (String.length str - 1) in
  let vars = TVOp.vars ty in
  let s1 = MVarSet.elements1 vars
  |> List.map (fun tv -> tv, TVar.mk kind (Some (Sstt.Var.name tv |> drop1)) |> TVar.typ) in
  let s2 = MVarSet.elements2 vars
  |> List.map (fun rv -> rv, RVar.mk kind (Some (Sstt.RowVar.name rv |> drop1)) |> Row.id_for) in
  let s = Subst.of_list s1 s2 in
  Subst.apply s ty
let sigs_of_ty mono ty =
  let aux ty =
    match Arrow.dnf ty with
    | [arrs] ->
      arrs |> List.map
        (fun (a,b) ->
          let a = Rstt.Arg.reidentify ~id:(TVar.mk KInfer None |> TVar.typ) a in
          Arrow.mk a b
        )
    | _ -> [ty]
  in
  let aux_p { Rstt.Attr.content ; classes } =
    aux content |> List.map (fun content -> Rstt.Attr.mk {Rstt.Attr.content ; classes})
  in
  let aux_n a = [Rstt.Attr.mk a |> Ty.neg] in
  let aux (ps, ns) =
    (List.concat_map aux_n ns)@(List.concat_map aux_p ps)
  in
  let aux ty =
    match Rstt.Attr.destruct ty with
    | [line] -> aux line
    | _ -> [ty]
  in
  let ty = refresh_vars KNoInfer ty in
  (aux ty, GTy.mk ty |> TyScheme.mk_poly_except mono |> simplify_tl)
let extend_env mlast env =
  let fv = System.Ast.fv mlast in
  let dom = Env.domain env |> VarSet.of_list in
  let missing = VarSet.diff fv dom in
  missing |> VarSet.elements |> List.fold_left
    (fun env v -> Env.add v (TyScheme.mk_mono GTy.dyn) env) env

type typing_ctx = { idenv: Variable.t StrMap.t ; tenv: Env.t ; benv: Types.Builder.env ; senv: Ty.t list VarMap.t }
let initial_ctx = { benv=Rstt.Builder.empty_env ; idenv=StrMap.empty ; tenv=Defs.initial_env ; senv=VarMap.empty }

let infer ctx mlast =
  let env = extend_env mlast ctx.tenv in
  let renvs = System.Refinement.refinements env mlast in
  (* REnvSet.elements renvs |> List.iter (fun renv -> Format.printf "Renv: %a@." REnv.pp renv) ; *)
  let anns = System.Reconstruction.infer ~direct_narrowing:true env renvs mlast in
  System.Checker.typeof_def env anns mlast |> simplify_tl

let treat_ast v ctx ast =
  try
    let typ = match VarMap.find_opt v ctx.senv with
    | None ->
      let mlast = Transform.to_mlsem { env=ctx.tenv ; infer_mode=true } ast in
      (* Format.printf "%a@.@." System.Ast.pp mlast ; *)
      infer ctx mlast
    | Some sigs ->
      let mlast = Transform.to_mlsem { env=ctx.tenv ; infer_mode=false } ast in
      (* Format.printf "%a@.@." System.Ast.pp mlast ; *)
      let asts = List.map (fun s -> Mlsem_system.Ast.coerce CheckStatic (GTy.mk s) mlast) sigs in
      let _ = List.map (infer ctx) asts in
      Env.find v ctx.tenv
    in
    Format.printf "%a:@? @[%a@]@.@." Variable.pp v TyScheme.pp_short typ ;
    ctx
  with System.Checker.Untypeable (err) ->
    Format.printf "Untypeable: %s@." err.title ;
    err.descr |> Option.iter (Format.printf "%s@.") ;
    Format.printf "@." ; ctx

let dummy_var = Variable.create (Some "_")
let treat_def ctx past =
  let (eid,ast) = PAst.transform { PAst.id = Scope.from_toplevel ctx.tenv ctx.idenv } past in
  (* Format.printf "%a@.@." Ast.pp_e (id,ast) ; *)
  match ast with
  | VarAssign (v, e) -> treat_ast v ctx e
  | _ -> treat_ast dummy_var ctx (eid, ast)

let add_sig ctx str tye =
  let open R_types.Types in
  let open Mlsem_common in
  let benv, ty = Builder.resolve ctx.benv tye in
  let ty = ty |> Builder.build Builder.TIdMap.empty in
  let (s,ty) = sigs_of_ty (Mlsem.Common.Env.tvars ctx.tenv) ty in
  let v,s,ty =
    match StrMap.find_opt str ctx.idenv with
    | None ->
        let v = MVariable.create Immut (Some str) in
        v,s,ty
    | Some v ->
      let ty =
        if Env.mem v ctx.tenv
        then merge_tl [ty ; (Env.find v ctx.tenv)]
        else ty
      in
      let s =
        if VarMap.mem v ctx.senv
        then (VarMap.find v ctx.senv)@s
        else s
      in
      v,s,ty
  in
  let idenv = StrMap.add str v ctx.idenv in
  (* Format.printf "Adding %s: @[%a@]@." str TyScheme.pp ty ; *)
  let tenv = Mlsem.Common.Env.replace v ty ctx.tenv in
  let senv = VarMap.add v s ctx.senv in
  { benv ; idenv ; tenv ; senv }

let add_def ctx def =
  match def with
  | Sigs.Sig (str, tye) -> add_sig ctx str tye
  | Sigs.Alias _ -> failwith "TODO"

let treat_extra ctx extra =
  match extra with
  | `Comment (_loc, (_, str)) ->
    if String.starts_with ~prefix:"##" str then
      let str = String.sub str 2 ((String.length str) - 2) in
      let (str, tye) = IO.parse_sig_def str in
      add_sig ctx str tye
    else ctx

let main () =
  (* System.Config.infer_overload := false ; *)
  Mlsem.Lang.Config.void_ty := Transform.typeof_const CNull ;
  (* TODO: use a regular r file with only type annotations instead of a special mli file *)
  let tdefs = R_types.IO.parse_type_defs_file "types.mli" in
  let ctx = List.fold_left add_def initial_ctx tdefs in
  (* Format.printf "%a@.@." Env.pp env ; *)
  let res = Parse.file "test.r" in
  match res.program with
  | None -> ()
  | Some prog ->
    (* Boilerplate.dump_extras res.extras ; *)
    let ctx = List.fold_left treat_extra ctx res.extras in
    let tree = Boilerplate.map_program () prog in
    let prog = Parser.of_parser tree in
    (* Format.printf "%a@.@." PAst.pp prog ; *)
    List.fold_left treat_def ctx prog |> ignore

let () =
  Mlsem.Types.Recording.start_recording () ;
  Printexc.record_backtrace true ;
  Mlsem_types.PEnv.add_printer_param (Rstt.Pp.printer_params ()) ;
  Mlsem_system.Config.normalization_fun := Rstt.Simplify.partition_vecs ;
  PEnv.sequential_handler PEnv.empty main () |> ignore ;
  Mlsem.Types.Recording.save_to_file "instances.json" (Mlsem.Types.Recording.tally_calls ())
