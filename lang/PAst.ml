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
| Binop of string * (e * e)
| Call of e * arg option list
| Function of bool (* \x fun? *) * param list option * e
| Braced of e list
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
and param =
| NoDefault of arg_id
| Default of arg_id * e

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
let aux_param f p =
  match p with
  | NoDefault arg -> Ast.NoDefault (id_of_argid arg)
  | Default (arg, e) -> Ast.Default (id_of_argid arg, f e)

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
  | Unop (str, e) -> Ast.Unop (var env (str^"__1"), aux_e env e)
  | Binop (str, (e1,e2)) ->
    begin match str, e1, e2 with
    | "<-", (_, Id id), e2 -> Ast.VarAssign (false, var env id, aux_e env e2)
    | "<<-", (_, Id id), e2 -> Ast.VarAssign (true, var env id, aux_e env e2)
    | _, _, _ -> Ast.Binop (var env (str^"__2"), aux_e env e1, aux_e env e2)
    end
  | Call (e,args) ->
    let e = aux_e env e in
    let args = List.mapi (aux_arg (aux_e env)) args in
    let args = List.filter_map Fun.id args in
    Ast.Call (e, args)
  | Function (_,params,e) ->
    (* TODO: update env *)
    let params =
      match params with
      | None -> []
      | Some lst -> List.map (aux_param (aux_e env)) lst
    in
    Ast.Function (params, aux_e env e)
  | Braced es ->
    (* TODO: update env *)
    Ast.Braced (List.map (aux_e env) es)
  in
  eid, e

let transform env t = aux_e env t
