(*
TODO:
- Normalization: only normalize when a non-any vector component is present? (cf. type of test_classes)
- Ellipsis
- Attributes?
- Error localization
- Type aliases that could be used both as a struct type and type
*)

open Mlsem.Common
module MVariable = Mlsem.Lang.MVariable

type const =
| CChr of string
| CDbl of string
| CInt of int
| CClx of string
| CLgl of bool
| CNull
[@@deriving show]

type e' =
| Const of const
| Id of Variable.t
| Declare of Variable.t * e
| Let of Variable.t * e * e
| VarAssign of Variable.t * e
| Unop of Variable.t * e
| Binop of Variable.t * e * e
| Call of e * e option MetaEnv.arg list
| Ite of e * e * e
| While of e * e
| For of Variable.t option * e * e
| TyCheck of { e:e ; ty:Mlsem.Types.Ty.t; necessary:bool; sufficient:bool }
| Function of param list * e
| Seq of e * e
| Return of e option | Break | Next
[@@deriving show]
and param = NoDefault of Variable.t | Default of Variable.t * e | Ellipsis
[@@deriving show]
and e = Eid.t * e'
[@@deriving show]

let map f e =
  let rec aux (id,e) =
    let e =
      match e with
      | Const _ | Id _ -> e
      | Declare (v, e) -> Declare (v, aux e)
      | Let (v, e1, e2) -> Let (v, aux e1, aux e2)
      | VarAssign (v, e) -> VarAssign (v, aux e)
      | Unop (v, e) -> Unop (v, aux e)
      | Binop (v, e1, e2) -> Binop (v, aux e1, aux e2)
      | Call (e, args) -> Call (aux e, List.map (fun (l,e) -> l, Option.map aux e) args)
      | Ite (e,e1,e2) -> Ite (aux e, aux e1, aux e2)
      | While (e, e') -> While (aux e, aux e')
      | For (vo, e, e') -> For (vo, aux e, aux e')
      | TyCheck {e;ty;necessary;sufficient} -> TyCheck {e=aux e ; ty ; necessary ; sufficient}
      | Function (ps, e) ->
        let aux' = function
        | NoDefault v -> NoDefault v
        | Default (v,e) -> Default (v, aux e)
        | Ellipsis -> Ellipsis
        in
        Function (List.map aux' ps, aux e)
      | Seq (e1,e2) -> Seq (aux e1, aux e2)
      | Return eo -> Return (Option.map aux eo) | Break -> Break | Next -> Next
    in
    f (id,e)
  in
  aux e
