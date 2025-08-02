
type const =
| CStr of string
[@@deriving show]

type e =
| Const of const
| Id of string
| Call of e * arg option list
[@@deriving show]
and arg =
| Unnamed of e
| Named of arg_id * e option
and arg_id =
| NullId
| ArgId of string
(* TODO: dots *)

type t = e list
[@@deriving show]

let aux_const _ = failwith "TODO"

let aux_e e =
  match e with
  | Const c -> aux_const c
  | Id _ -> failwith "TODO"
  | Call _ -> failwith "TODO"

let transform t = aux_e t
