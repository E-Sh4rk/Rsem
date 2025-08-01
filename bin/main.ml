open Tree_sitter_r
open Lang

(* let () =
  Tree_sitter_run.Main.run
    ~lang:"r"
    ~parse_source_file:Parse.parse_source_file
    ~parse_input_tree:Parse.parse_input_tree
    ~dump_tree:Boilerplate.dump_tree
    ~dump_extras:Boilerplate.dump_extras *)

let () =
  let res = Parse.file "test.r" in
  match res.program with
  | None -> ()
  | Some prog ->
    Boilerplate.dump_extras res.extras ;
    let tree = Boilerplate.map_program () prog in
    let ast = Parser.of_parser tree in
    Format.printf "%a" Ast.pp ast
