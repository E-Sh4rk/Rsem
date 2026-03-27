open Rstt

type sig_def = string * (string,string,string) Builder.t
type alias_def = string * (string,string,string) Builder.t

type elt =
| Sig of sig_def
| Alias of alias_def
type t = elt list
