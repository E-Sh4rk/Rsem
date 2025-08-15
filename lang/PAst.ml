open R_types
open Common
open Sigs

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

let rec bv_e (_,e) =
  match e with
  | Const _ | Id _ | Function _ -> StrSet.empty
  | Unop (_,e) -> bv_e e
  | Binop (str, (e1, e2)) ->
    let res = match str, e1, e2 with
    | "<-", (_, Id id), _
    | "<<-", (_, Id id), _ -> StrSet.singleton id
    | _, _, _ -> StrSet.empty
    in
    StrSet.union res (StrSet.union (bv_e e1) (bv_e e2))
  | Call (e, args) ->
    let es = args |> List.concat_map (function
      | None  | Some (Named (_, None)) -> []
      | Some (Unnamed e) | Some (Named (_, Some e)) -> [e]
      )
    in
    bv_es (e::es)
  | Braced es -> bv_es es
and bv_es es =
  List.map bv_e es |> List.fold_left StrSet.union StrSet.empty

module StrMap = Map.Make(String)
type env = { id: Variable.t StrMap.t ; sigs: Sig.t }

let var env str =
  match StrMap.find_opt str env.id with
  | None -> Variable.create_let (Some str)
  | Some v -> v

let id_of_argid aid =
  match aid with
  | NullId -> Args.id_of_null
  | ArgId str -> str
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
let aux_param env f p =
  match p with
  | NoDefault arg ->
    Ast.NoDefault (id_of_argid arg, var env (id_of_argid arg))
  | Default (arg, e) ->
    Ast.Default (id_of_argid arg, var env (id_of_argid arg), f e)

let aux_const c =
  match c with
  | CStr str -> Ast.CChr str
  | CFloat str -> Ast.CDbl str
  | CBool b -> Ast.CLgl b
  | CNull -> Ast.CNull

let add_var ~lambda env str =
  let v =
    if lambda
    then Variable.create_lambda (Some str)
    else Variable.create_let (Some str)
  in
  StrMap.add str v env

let add_def pid eid e str =
  let def =
    match StrMap.find_opt str pid with
    | None -> None
    | Some v -> Some (Eid.dummy, Ast.Id v)
  in
  let v = StrMap.find str eid in
  Eid.dummy, Ast.Declare (v, def, e)
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
    let finfo = match e with
    | (_, Id v) -> Sig.get_info env.sigs v
    | _ -> FunInfo.unk
    in
    let args = List.mapi (aux_arg (aux_e env)) args in
    let args = List.filter_map Fun.id args in
    Ast.Call (e, args, finfo)
  | Function (_,params,e) ->
    (* Params *)
    let pbvs =
      match params with
      | None -> StrSet.empty
      | Some lst -> bv_params lst
    in
    let pid = List.fold_left (add_var ~lambda:true) env.id (StrSet.elements pbvs) in
    let env = { env with id=pid } in
    let params =
      match params with
      | None -> []
      | Some lst -> List.map (aux_param env (aux_e env)) lst
    in
    (* Body *)
    let ebvs = bv_e e in
    let eid = List.fold_left (add_var ~lambda:false) env.id (StrSet.elements ebvs) in
    let env = { env with id=eid } in
    let e = List.fold_left (add_def pid eid) (aux_e env e) (StrSet.elements ebvs) in
    Ast.Function (params, e)
  | Braced es -> Ast.Braced (List.map (aux_e env) es)
  in
  eid, e

let transform env t = aux_e env t
