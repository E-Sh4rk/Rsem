open Tree_sitter_r
open Lang
open R_types
open Types
open Common

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
    let anns = System.Reconstruction.infer env renvs mlast in
    let typ = System.Checker.typeof_def env anns mlast in
    let typ = Types.TyScheme.norm_and_simpl typ in
    Format.printf "%a: %a@.@." Variable.pp v Types.TyScheme.pp_short typ ;
    idenv, env
  with System.Checker.Untypeable (err) ->
    Format.printf "Untypeable: %s@." err.title ;
    err.descr |> Option.iter (Format.printf "%s@.") ;
    idenv, env

let dummy_var = Variable.create_gen (Some "_")
let treat_def (idenv, env) past =
  let (id,ast) = PAst.transform { PAst.id = idenv } past in
  (* Format.printf "%a@.@." Ast.pp_e (id,ast) ; *)
  match ast with
  | VarAssign (false, v, e) -> treat_ast v (idenv, env) e
  | _ -> treat_ast dummy_var (idenv, env) (id, ast)

let add_def (tenv, idenv, env) def =
  let open R_types.Types in
  match def with
  | RBuilder.Sig (str, tye) ->
    let ty, _ = RBuilder.type_expr_to_typ tenv RBuilder.empty_vtenv tye in
    let v = Variable.create_let (Some str) in
    let idenv = StrMap.add str v idenv in
    let env = Env.add v (TyScheme.mk_poly (GTy.mk ty)) env in
    tenv, idenv, env
  | RBuilder.Aliases lst ->
    let tenv = RBuilder.define_aliases tenv RBuilder.empty_vtenv lst in
    tenv, idenv, env


let () =
  Printexc.record_backtrace true ;
  System.Config.infer_overload := false ;
  let tdefs = R_types.IO.parse_type_defs_file "types.mli" in
  let _, idenv, env =
    List.fold_left add_def (RBuilder.empty_tenv, StrMap.empty, Defs.initial_env) tdefs in
  Format.printf "%a@.@." Env.pp env ;
  let res = Parse.file "test.r" in
  match res.program with
  | None -> ()
  | Some prog ->
    Boilerplate.dump_extras res.extras ;
    let tree = Boilerplate.map_program () prog in
    let prog = Parser.of_parser tree in
    Format.printf "%a@.@." PAst.pp prog ;
    List.fold_left treat_def (idenv, env) prog |> ignore
