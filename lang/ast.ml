
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
| Function of param list * e
| Braced of e list
[@@deriving show]
and arg = label * e
[@@deriving show]
and param = NoDefault of label * Variable.t | Default of label * Variable.t * e
[@@deriving show]
and e = Eid.t * e'
[@@deriving show]
