open R_types
open Common

module Position = struct
  type t = Position.t
  let pp fmt _ = Format.fprintf fmt "_"
end

type const =
| CStr of string
| CFloat of string
| CBool of bool
| CNull
[@@deriving show]

type e' =
| Const of const
| Id of string
| Unop of string * e
| Call of e * arg option list
[@@deriving show]
and arg =
| Unnamed of e
| Named of arg_id * e option
and e = Position.t * e'
[@@deriving show]
and arg_id =
| NullId
| EllipsisId
| ArgId of string

type t = e list
[@@deriving show]

module StrMap = Map.Make(String)
type env = { id: Variable.t StrMap.t }

let empty_env = { id = StrMap.empty }

let id_of_argid aid =
  match aid with
  | NullId -> Args.id_of_null
  | ArgId str -> Args.id_of_name str
  | EllipsisId -> Args.id_of_ellipsis
let id_of_pos i =
  Args.id_of_pos i

let aux_arg f i arg =
  match arg with
  | Unnamed e ->
    id_of_pos i, f e
  | Named (aid, Some e) ->
    id_of_argid aid, f e
  | Named (_, None) -> failwith "TODO: Named absent arguments"
let aux_arg f i arg =
  Option.map (aux_arg f i) arg

let aux_const c =
  match c with
  | CStr str -> Ast.CChr str
  | CFloat str -> Ast.CDbl str
  | CBool b -> Ast.CLgl b
  | CNull -> Ast.CNull

let var env str =
  match StrMap.find_opt str env.id with
  | None -> Variable.create_let (Some str)
  | Some v -> v

let rec aux_e env (pos,e) =
  let eid = Eid.unique_with_pos pos in
  let e = match e with
  | Const c -> Ast.Const (aux_const c)
  | Id str -> Ast.Id (var env str)
  | Unop (str, e) -> Ast.Unop (var env str, aux_e env e)
  | Call (e,args) ->
    let e = aux_e env e in
    let args = List.mapi (aux_arg (aux_e env)) args in
    let args = List.filter_map Fun.id args in
    Ast.Call (e, args)
  in
  eid, e

let transform env t = aux_e env t
