open Tree_sitter_r
open Lang
open Common

(* let () =
  Tree_sitter_run.Main.run
    ~lang:"r"
    ~parse_source_file:Parse.parse_source_file
    ~parse_input_tree:Parse.parse_input_tree
    ~dump_tree:Boilerplate.dump_tree
    ~dump_extras:Boilerplate.dump_extras *)

module StrMap = Map.Make(String)

let treat_def (idenv, env) past =
  let ast = PAst.transform { PAst.id = idenv } past in
  Format.printf "%a@.@." Ast.pp_e ast ;
  let mlast = Transform.to_mlsem ast in
  Format.printf "%a@.@." System.Ast.pp mlast ;
  let renvs = System.Refinement.refinement_envs env mlast in
  let anns = System.Reconstruction.infer env renvs mlast in
  let typ = System.Checker.typeof_def env anns mlast in
  Format.printf "%a@.@." Types.TyScheme.pp typ ;
  idenv, env

let add_def (idenv, env) (str, tye) =
  let open R_types.Types in
  let ty, _ = Builder.type_expr_to_typ Builder.empty_tenv Builder.empty_vtenv tye in
  let v = Variable.create_let (Some str) in
  let idenv = StrMap.add str v idenv in
  let env = Env.add v (TyScheme.mk_poly (GTy.mk ty)) env in
  idenv, env

let () =
  let tdefs = R_types.IO.parse_type_defs_file "types.mli" in
  let idenv, env =
    List.fold_left add_def (StrMap.empty, Env.empty) tdefs in
  let res = Parse.file "test.r" in
  match res.program with
  | None -> ()
  | Some prog ->
    Boilerplate.dump_extras res.extras ;
    let tree = Boilerplate.map_program () prog in
    let prog = Parser.of_parser tree in
    Format.printf "%a@.@." PAst.pp prog ;
    List.fold_left treat_def (idenv, env) prog |> ignore
