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

module StrSet = Set.Make(String)

let bv_param p =
  match p with
  | NoDefault (ArgId str) -> StrSet.singleton str
  | Default (ArgId str, _) -> StrSet.singleton str
  | _ -> StrSet.empty
let bv_params ps =
  List.map bv_param ps |> List.fold_left StrSet.union StrSet.empty

let bv_e _ = failwith "TODO"
let bv_es es =
  List.map bv_e es |> List.fold_left StrSet.union StrSet.empty

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

let add_var ~lambda env str =
  let v =
    if lambda
    then Variable.create_lambda (Some str)
    else Variable.create_let (Some str)
  in
  StrMap.add str v env

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
    (* TODO: declare bvs in body (they need to be references) *)
    let env, params =
      match params with
      | None -> env, []
      | Some lst ->
        let bvs = bv_params lst in
        let id = List.fold_left (add_var ~lambda:true) env.id (StrSet.elements bvs) in
        let env = { id } in
        env, List.map (aux_param (aux_e env)) lst
    in
    Ast.Function (params, aux_e env e)
  | Braced es ->
    let bvs = bv_es es in
    let id = List.fold_left (add_var ~lambda:true) env.id (StrSet.elements bvs) in
    let env = { id } in
    (* TODO: declare bvs *)
    Ast.Braced (List.map (aux_e env) es)
  in
  eid, e

let transform env t = aux_e env t
