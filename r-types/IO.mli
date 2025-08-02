open Types.Builder
open Common
open Defs

exception LexicalError of Position.t * string
exception SyntaxError of Position.t * string

val parse_type_defs_file : string -> type_defs
val parse_type_string : string -> type_expr
