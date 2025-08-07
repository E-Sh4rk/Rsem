
open Common

type label = string
[@@deriving show]

type const =
| CChr of string
| CDbl of string
| CLgl of bool
| CNull
[@@deriving show]

type e' =
| Const of const
| Id of Variable.t
| Unop of Variable.t * e
| Call of e * arg list
[@@deriving show]
and arg = label * e
[@@deriving show]
and e = Eid.t * e'
[@@deriving show]
