
open Common

type label = string
[@@deriving show]

type const =
| CChr of string
| CDbl of string
| CLgl of bool
| CNull
| CUnit
[@@deriving show]

type e' =
| Hole
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
| Seq of e * e
| Return of e option
[@@deriving show]
and arg = arg_label * e
[@@deriving show]
and arg_label = Positional | Named of label
[@@deriving show]
and param = NoDefault of Variable.t | Default of Variable.t * e | Ellipsis
[@@deriving show]
and e = Eid.t * e'
[@@deriving show]

let rec map f (id,e) =
  let e =
    match e with
    | Hole | Const _ | Id _ -> e
    | Declare (v, eo, e) -> Declare (v, Option.map (map f) eo, map f e)
    | Let (v, e1, e2) -> Let (v, map f e1, map f e2)
    | VarAssign (b, v, e) -> VarAssign (b, v, map f e)
    | Unop (v, e) -> Unop (v, map f e)
    | Binop (v, e1, e2) -> Binop (v, map f e1, map f e2)
    | Call (e, args) -> Call (map f e, List.map (fun (l,e) -> l, map f e) args)
    | Ite (e,e1,e2) -> Ite (map f e, map f e1, map f e2)
    | Function (ps, e) ->
      let aux = function
      | NoDefault v -> NoDefault v
      | Default (v,e) -> Default (v, map f e)
      | Ellipsis -> Ellipsis
      in
      Function (List.map aux ps, map f e)
    | Seq (e1,e2) -> Seq (map f e1, map f e2)
    | Return eo -> Return (Option.map (map f) eo)
  in
  f (id,e)

let fill_hole e elt =
  map (function (_, Hole) -> elt | e -> e) e

let hole = Eid.dummy, Hole
