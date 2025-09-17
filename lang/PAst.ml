open Mlsem.Common
module MVariable = Mlsem.Lang.MVariable

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
| Ite of e * e * e option
| Braced of e list
| Return
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
  | Return | Const _ | Id _ | Function _ -> StrSet.empty
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
  | Ite (e, e1, e2) -> bv_es (e::e1::(match e2 with None -> [] | Some e2 -> [e2]))
  | Braced es -> bv_es es
and bv_es es =
  List.map bv_e es |> List.fold_left StrSet.union StrSet.empty

module StrMap = Map.Make(String)
type env = { id: Variable.t StrMap.t }

(* TODO: have a distinct call env and val env. *)
let var env str =
  match StrMap.find_opt str env.id with
  | None ->
    begin match Ast.BuiltinOp.find_builtin str with
    | None -> Variable.create_let (Some str)
    | Some v -> v
    end
  | Some v -> v

let aux_arg f arg =
  match arg with
  | Unnamed e ->
    Some (Ast.Positional, f e)
  | Named (ArgId str, Some e) ->
    Some (Ast.Named str, f e)
  | Named (_, None) -> None
  | _ -> assert false
let aux_arg f arg =
  Option.bind arg (aux_arg f)
let aux_param env f p =
  match p with
  | NoDefault EllipsisId -> Ast.Ellipsis
  | Default (EllipsisId, _) -> assert false
  | NoDefault (ArgId str) -> Ast.NoDefault (var env str)
  | Default (ArgId str, e) -> Ast.Default (var env str, f e)
  | NoDefault NullId | Default (NullId, _) -> assert false

let aux_const c =
  match c with
  | CStr str -> Ast.CChr str
  | CFloat str -> Ast.CDbl str
  | CBool b -> Ast.CLgl b
  | CNull -> Ast.CNull

let add_var ~lambda env str =
  let v =
    if lambda
    then MVariable.create_lambda MVariable.Mut (Some str)
    else MVariable.create_let MVariable.Mut (Some str)
  in
  StrMap.add str v env

let add_def pid eid e str =
  let v = StrMap.find str eid in
  match StrMap.find_opt str pid with
  | None -> Eid.unique (), Ast.Declare (v, e)
  | Some v -> Eid.unique (), Ast.Let (v, (Eid.unique (), Ast.Id v), e)

let rec aux_e env (pos,e) =
  let eid = Eid.unique_with_pos pos in
  let e = match e with
  | Return -> assert false
  | Const c -> Ast.Const (aux_const c)
  | Id str -> Ast.Id (var env str)
  | Unop (str, e) -> Ast.Unop (var env (str^"__1"), aux_e env e)
  | Binop (str, (e1,e2)) ->
    begin match str, e1, e2 with
    | "<-", (_, Id id), e2 -> Ast.VarAssign (var env id, aux_e env e2)
    | "<<-", (_, Id _), _ -> failwith "TODO"
    | _, _, _ -> Ast.Binop (var env (str^"__2"), aux_e env e1, aux_e env e2)
    end
  | Call ((_, Return),[]) -> Ast.Return None
  | Call ((_, Return),[Some (Unnamed e)]) -> Ast.Return (Some (aux_e env e))
  | Call (e,args) ->
    let e = aux_e env e in
    let args = List.filter_map (aux_arg (aux_e env)) args in
    Ast.Call (e, args)
  | Ite (e, e1, e2) ->
    let e, e1 = aux_e env e, aux_e env e1 in
    let e2 = match e2 with None -> Eid.unique (), Ast.Const Ast.CNull | Some e2 -> aux_e env e2 in
    Ast.Ite (e, e1, e2)
  | Function (_,params,e) ->
    (* Params *)
    let pbvs =
      match params with
      | None -> StrSet.empty
      | Some lst -> bv_params lst
    in
    let pid = List.fold_left (add_var ~lambda:true) env.id (StrSet.elements pbvs) in
    let env = { id=pid } in
    let params =
      match params with
      | None -> []
      | Some lst -> List.map (aux_param env (aux_e env)) lst
    in
    (* Body *)
    let ebvs = bv_e e in
    let eid = List.fold_left (add_var ~lambda:false) env.id (StrSet.elements ebvs) in
    let env = { id=eid } in
    let e = List.fold_left (add_def pid eid) (aux_e env e) (StrSet.elements ebvs) in
    Ast.Function (params, e)
  | Braced [] -> Ast.Const Ast.CNull
  | Braced (e::es) ->
    List.fold_left (fun acc e -> Eid.unique (), Ast.Seq (acc, aux_e env e)) (aux_e env e) es |> snd
  in
  eid, e

let transform env t = aux_e env t
