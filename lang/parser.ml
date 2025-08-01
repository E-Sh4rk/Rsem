open Tree_sitter_run

let of_parser tree =
  Raw_tree.to_channel stdout tree ;
  failwith "TODO"
