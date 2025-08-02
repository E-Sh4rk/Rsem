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
