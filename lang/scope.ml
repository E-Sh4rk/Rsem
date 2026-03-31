open Mlsem.Common
open Mlsem.Types
module MVariable = Mlsem.Lang.MVariable
module StrMap = Map.Make(String)

type kind = KFun | KVal | KAny | KAnyOpt
type env = (kind * Variable.t) StrMap.t
type t = env list

exception ScopeError of string

let fun_ty = Arrow.any |> Rstt.Attr.mk_anyclass
let from_toplevel env idmap =
  let env = idmap |> StrMap.map (fun v ->
    if Env.mem v env
    then
      let ty = Env.find v env |> TyScheme.get |> snd |> GTy.ub in
      if Ty.leq ty fun_ty then KFun, v
      else if Ty.leq ty (Ty.neg fun_ty) then KVal, v
      else KAny, v
    else KAny, v
    ) in
  [ env ]

let new_scope t = StrMap.empty::t
let add_local_binding str kind t =
  match t with
  | [] -> assert false
  | env::_ when StrMap.mem str env -> raise (ScopeError ("Symbol "^str^" already defined"))
  | env::t ->
    let v = MVariable.create Mut (Some str) in
    let env = StrMap.add str (kind,v) env in
    env::t

let unresolved str =
  begin match Ast.BuiltinOp.find_builtin str with
  | None -> MVariable.create Immut (Some str)
  | Some v -> v
  end

let rec resolve_call str t =
  match t with
  | [] -> assert false
  | [tl] when StrMap.mem str tl -> StrMap.find str tl |> snd
  | [_] -> unresolved str
  | env::t when StrMap.mem str env ->
    begin match StrMap.find str env with
    | KFun, v -> v
    | KVal, _ -> resolve_call str t
    | KAny, _ | KAnyOpt, _ -> raise (ScopeError ("Cannot resolve symbol "^str))
    end
  | _::t -> resolve_call str t

let rec resolve str t =
  match t with
  | [] -> assert false
  | [tl] when StrMap.mem str tl -> StrMap.find str tl |> snd
  | [_] -> unresolved str
  | env::_ when StrMap.mem str env ->
    begin match StrMap.find str env with
    | KFun, v | KVal, v | KAny, v -> v
    | KAnyOpt, _ -> raise (ScopeError ("Cannot resolve symbol "^str))
    end
  | _::t -> resolve str t

let resolve_parent str t =
  match t with
  | [] -> assert false
  | _::t -> resolve str t
