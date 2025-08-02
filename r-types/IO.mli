open Types.Builder
open Common

exception LexicalError of Position.t * string
exception SyntaxError of Position.t * string

(* val parse_type_file : string ->  *)
val parse_type_string : string -> type_expr
