open Common
open R_types

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

module StrMap = Map.Make(String)
type env = { id: Variable.t StrMap.t }

let empty_env = { id = StrMap.empty }

let id_of_argid aid =
  match aid with
  | NullId -> Args.id_of_null
  | ArgId str -> Args.id_of_name str
let id_of_pos i =
  Args.id_of_pos i

let aux_arg f i arg =
  match arg with
  | Unnamed e ->
    id_of_pos i, Some (f e)
  | Named (aid, e) ->
    id_of_argid aid, Option.map f e
let aux_arg f i arg =
  match arg with
  | None -> id_of_pos i, None
  | Some arg -> aux_arg f i arg

let aux_const c =
  match c with
  | CStr str -> Ast.CStr str

let var env str =
  match StrMap.find_opt str env.id with
  | None -> Variable.create_let (Some str)
  | Some v -> v

let rec aux_e env e =
  match e with
  | Const c -> Ast.Const (aux_const c)
  | Id str -> Ast.Id (var env str)
  | Call (e,args) ->
    let e = aux_e env e in
    let args = List.mapi (aux_arg (aux_e env)) args in
    Ast.Call (e, args)

let transform env t = aux_e env t
