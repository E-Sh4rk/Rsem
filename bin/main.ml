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
(* let sigs_of_ty mono ty =
  let rec aux ty =
    match Arrow.dnf ty with
    | [arrs] ->
      let arrs = arrs |> List.concat_map
        (fun (a,b) -> aux b |> List.map (fun b -> Arrow.mk a b))
      in
      if Ty.equiv ty (Ty.conj arrs)
      then arrs else [ty]
    | _ -> [ty]
  in
  if TVOp.vars ty
    |> MVarSet.filter
      (fun tv -> TVar.has_kind KNoInfer tv |> not)
      (fun rv -> RVar.has_kind KNoInfer rv |> not)
    |> MVarSet.is_empty
  then Some (aux ty, GTy.mk ty |> TyScheme.mk_poly_except mono |> simplify_tl)
  else None *)

type typing_ctx = { idenv: Variable.t StrMap.t ; tenv: Env.t ; benv: Types.Builder.env }
let initial_ctx = { benv=Rstt.Builder.empty_env ; idenv=StrMap.empty ; tenv=Defs.initial_env }

let extend_env mlast env =
  let fv = System.Ast.fv mlast in
  let dom = Env.domain env |> VarSet.of_list in
  let missing = VarSet.diff fv dom in
  missing |> VarSet.elements |> List.fold_left
    (fun env v -> Env.add v (TyScheme.mk_mono GTy.dyn) env) env

let treat_ast v ctx ast =
  try
    let mlast = Transform.to_mlsem { env=ctx.tenv ; infer_mode=true } ast in
    (* Format.printf "%a@.@." System.Ast.pp mlast ; *)
    let env = extend_env mlast ctx.tenv in
    let renvs = System.Refinement.refinements env mlast in
    (* REnvSet.elements renvs |> List.iter (fun renv -> Format.printf "Renv: %a@." REnv.pp renv) ; *)
    let anns = System.Reconstruction.infer ~direct_narrowing:true env renvs mlast in
    let typ = System.Checker.typeof_def env anns mlast |> simplify_tl in
    Format.printf "%a:@? @[%a@]@.@." Variable.pp v TyScheme.pp_short typ ;
    ctx
  with System.Checker.Untypeable (err) ->
    Format.printf "Untypeable: %s@." err.title ;
    err.descr |> Option.iter (Format.printf "%s@.") ;
    ctx

let dummy_var = Variable.create (Some "_")
let treat_def ctx past =
  let (eid,ast) = PAst.transform { PAst.id = ctx.idenv } past in
  (* Format.printf "%a@.@." Ast.pp_e (id,ast) ; *)
  (* TODO: if def has already a signature, check it *)
  match ast with
  | VarAssign (v, e) -> treat_ast v ctx e
  | _ -> treat_ast dummy_var ctx (eid, ast)

let add_def ctx def =
  let open R_types.Types in
  match def with
  | Sigs.Sig (str, tye) ->
    let benv, ty = Builder.resolve ctx.benv tye in
    let ty = ty |> Builder.build Builder.TIdMap.empty in
    let v = MVariable.create Immut (Some str) in
    let idenv = StrMap.add str v ctx.idenv in
    let tenv = Mlsem.Common.Env.add v (TyScheme.mk_poly (GTy.mk ty)) ctx.tenv in
    { benv ; idenv ; tenv }
  | Sigs.Alias _ -> failwith "TODO"

let main () =
  (* System.Config.infer_overload := false ; *)
  Mlsem.Lang.Config.void_ty := Transform.typeof_const CNull ;
  let tdefs = R_types.IO.parse_type_defs_file "types.mli" in
  let ctx = List.fold_left add_def initial_ctx tdefs in
  (* Format.printf "%a@.@." Env.pp env ; *)
  let res = Parse.file "test.r" in
  match res.program with
  | None -> ()
  | Some prog ->
    (* Boilerplate.dump_extras res.extras ; *)
    (* TODO: add extra signatures to the list *)
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
