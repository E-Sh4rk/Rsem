
open Common

type label = string
[@@deriving show]

type const =
| CStr of string
[@@deriving show]

type e' =
| Const of const
| Id of Variable.t
| Call of e * arg list
[@@deriving show]
and arg = label * e
[@@deriving show]
and e = Eid.t * e'
[@@deriving show]
