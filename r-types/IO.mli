open Mlsem.Common

exception LexicalError of Position.t * string
exception SyntaxError of Position.t * string

val parse_type_defs_file : string -> RBuilder.type_defs
val parse_type_string : string -> RBuilder.type_expr
