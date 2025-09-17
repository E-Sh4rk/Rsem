
open Mlsem.Common
open R_types

type label = string
[@@deriving show]

type const =
| CChr of string
| CDbl of string
| CLgl of bool
| CNull
[@@deriving show]

type e' =
| Hole of int
| Const of const
| Id of Variable.t
| Declare of Variable.t * e option * e
| Let of Variable.t * e * e
| VarAssign of bool (* superassign *) * Variable.t * e
| Unop of Variable.t * e
| Binop of Variable.t * e * e
| Call of e * arg list
| Ite of e * e * e
| TyCheck of e * Types.Ty.t
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

module BuiltinOp = struct
  let eq = Variable.create_let (Some "==__2")
  let neq = Variable.create_let (Some "!=__2")
  let all = [ eq ; neq ]
  let find_builtin str =
    let f v =
      match Variable.get_name v with
      | None -> false
      | Some name -> String.equal name str
    in
    List.find_opt f all
end

let map f e =
  let rec aux (id,e) =
    let e =
      match e with
      | Hole _ | Const _ | Id _ -> e
      | Declare (v, eo, e) -> Declare (v, Option.map aux eo, aux e)
      | Let (v, e1, e2) -> Let (v, aux e1, aux e2)
      | VarAssign (b, v, e) -> VarAssign (b, v, aux e)
      | Unop (v, e) -> Unop (v, aux e)
      | Binop (v, e1, e2) -> Binop (v, aux e1, aux e2)
      | Call (e, args) -> Call (aux e, List.map (fun (l,e) -> l, aux e) args)
      | Ite (e,e1,e2) -> Ite (aux e, aux e1, aux e2)
      | TyCheck (e, ty) -> TyCheck (aux e, ty)
      | Function (ps, e) ->
        let aux' = function
        | NoDefault v -> NoDefault v
        | Default (v,e) -> Default (v, aux e)
        | Ellipsis -> Ellipsis
        in
        Function (List.map aux' ps, aux e)
      | Seq (e1,e2) -> Seq (aux e1, aux e2)
      | Return eo -> Return (Option.map aux eo)
    in
    f (id,e)
  in
  aux e

let map' f e =
  let rec aux (id,e) =
    match f (id, e) with
    | Some e -> e
    | None ->
      let e = match e with
      | Hole _ | Const _ | Id _ -> e
      | Declare (v, eo, e) -> Declare (v, Option.map aux eo, aux e)
      | Let (v, e1, e2) -> Let (v, aux e1, aux e2)
      | VarAssign (b, v, e) -> VarAssign (b, v, aux e)
      | Unop (v, e) -> Unop (v, aux e)
      | Binop (v, e1, e2) -> Binop (v, aux e1, aux e2)
      | Call (e, args) -> Call (aux e, List.map (fun (l,e) -> l, aux e) args)
      | Ite (e,e1,e2) -> Ite (aux e, aux e1, aux e2)
      | TyCheck (e,ty) -> TyCheck (aux e, ty)
      | Function (ps, e) ->
        let aux' = function
        | NoDefault v -> NoDefault v
        | Default (v,e) -> Default (v, aux e)
        | Ellipsis -> Ellipsis
        in
        Function (List.map aux' ps, aux e)
      | Seq (e1,e2) -> Seq (aux e1, aux e2)
      | Return eo -> Return (Option.map aux eo)
      in
      (id,e)
  in
  aux e

let fill_hole e n elt =
  map (function (_, Hole i) when i=n -> elt | e -> e) e

let hole n = Eid.dummy, Hole n

let fresh_hole_id =
  let n = ref 0 in
  fun () -> n := !n+1 ; !n
