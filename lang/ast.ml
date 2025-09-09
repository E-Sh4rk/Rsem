
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
| Declare of Variable.t * e option * e
| Let of Variable.t * e * e
| VarAssign of bool (* superassign *) * Variable.t * e
| Unop of Variable.t * e
| Binop of Variable.t * e * e
| Call of e * arg list
| Ite of e * e * e
| Function of param list * e
| Braced of e list
[@@deriving show]
and arg = arg_label * e
[@@deriving show]
and arg_label = Positional | Named of label
[@@deriving show]
and param = NoDefault of int * Variable.t | Default of int * Variable.t * e | Ellipsis
[@@deriving show]
and e = Eid.t * e'
[@@deriving show]
