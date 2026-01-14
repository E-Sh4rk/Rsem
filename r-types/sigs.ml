open Rstt

type elt =
| Sig of string * (string,string,string) Builder.t
| Alias of string * (string,string,string) Builder.t
type t = elt list
