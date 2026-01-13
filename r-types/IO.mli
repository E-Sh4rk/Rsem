open Rstt
open Mlsem_common

exception LexicalError of Position.t * string
exception SyntaxError of Position.t * string

val parse_type_defs_file : string -> Defs.t
val parse_type_string : string -> (string,string,string) Builder.t
