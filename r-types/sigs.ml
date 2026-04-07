open Rstt

type sig_def = string * (string,string,string) Builder.t
type alias_def = string * (string,string,string) Builder.t

type t =
| Sig of sig_def
| Alias of alias_def
