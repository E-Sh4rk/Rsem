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

let extend_env mlast env =
  let fv = System.Ast.fv mlast in
  let dom = Env.domain env |> VarSet.of_list in
  let missing = VarSet.diff fv dom in
  missing |> VarSet.elements |> List.fold_left
    (fun env v -> Env.add v (TyScheme.mk_mono GTy.dyn) env) env

let treat_ast v (idenv, env) ast =
  try
    let mlast = Transform.to_mlsem ast in
    (* Format.printf "%a@.@." System.Ast.pp mlast ; *)
    let env = extend_env mlast env in
    let renvs = System.Refinement.refinement_envs env mlast in
    (* REnvSet.elements renvs |> List.iter (fun renv -> Format.printf "Renv: %a@." REnv.pp renv) ; *)
    let anns = System.Reconstruction.infer env renvs mlast in
    let typ = System.Checker.typeof_def env anns mlast in
    let typ = TyScheme.norm_and_simpl typ in
    Format.printf "%a: @[%a@]@.@." Variable.pp v TyScheme.pp_short typ ;
    idenv, env
  with System.Checker.Untypeable (err) ->
    Format.printf "Untypeable: %s@." err.title ;
    err.descr |> Option.iter (Format.printf "%s@.") ;
    idenv, env

let dummy_var = Variable.create (Some "_")
let treat_def (idenv, env) past =
  let (id,ast) = PAst.transform { PAst.id = idenv } past in
  (* Format.printf "%a@.@." Ast.pp_e (id,ast) ; *)
  match ast with
  | VarAssign (v, e) -> treat_ast v (idenv, env) e
  | _ -> treat_ast dummy_var (idenv, env) (id, ast)

let add_struct_guards t =
  let open Rstt.Builder in
  let aux t =
    match t with
    | TArrow (l,r) -> TArrow (TStruct l,r)
    | t -> t
  in
  map aux Fun.id Fun.id t
let add_def (benv, idenv, env) def =
  let open R_types.Types in
  match def with
  | Sigs.Sig (str, tye) ->
    let benv, ty = Builder.resolve benv tye in
    let ty = ty |> add_struct_guards |> Builder.build Builder.TIdMap.empty in
    let v = MVariable.create Immut (Some str) in
    let idenv = StrMap.add str v idenv in
    let env = Env.add v (TyScheme.mk_poly (GTy.mk ty)) env in
    benv, idenv, env
  | Sigs.Alias _ -> failwith "TODO"

let main () =
  System.Config.infer_overload := false ;
  Mlsem.Lang.Config.void_ty := Transform.typeof_const CNull ;
  let tdefs = R_types.IO.parse_type_defs_file "types.mli" in
  let _, idenv, env =
    List.fold_left add_def (Rstt.Builder.empty_env, StrMap.empty, Defs.initial_env) tdefs in
  (* Format.printf "%a@.@." Env.pp env ; *)
  let res = Parse.file "test.r" in
  match res.program with
  | None -> ()
  | Some prog ->
    Boilerplate.dump_extras res.extras ;
    let tree = Boilerplate.map_program () prog in
    let prog = Parser.of_parser tree in
    (* Format.printf "%a@.@." PAst.pp prog ; *)
    List.fold_left treat_def (idenv, env) prog |> ignore

let () =
  Mlsem.Types.Recording.start_recording () ;
  Printexc.record_backtrace true ;
  Mlsem_types.PEnv.add_printer_param (Rstt.Pp.printer_params ()) ;
  Mlsem_system.Config.normalization_fun := Rstt.Simplify.partition_vecs ;
  PEnv.sequential_handler PEnv.empty main () |> ignore ;
  Mlsem.Types.Recording.save_to_file "instances.json" (Mlsem.Types.Recording.tally_calls ())
