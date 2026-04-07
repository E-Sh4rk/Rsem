open Rstt
open Mlsem_common

exception LexicalError of Position.t * string
exception SyntaxError of Position.t * string

val parse_type_defs_file : string -> Sigs.t
val parse_type_string : string -> (string,string,string) Builder.t
val parse_sig_def : string -> Sigs.sig_def
val parse_alias_def : string -> Sigs.alias_def
val parse_def : string -> Sigs.elt
