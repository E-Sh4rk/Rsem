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

let add str kind v t =
  match t with
  | [] -> assert false
  | env::t ->
    let env = StrMap.add str (kind,v) env in
    env::t

let rec resolve_call str t =
  match t with
  | [] -> assert false
  | [tl] when StrMap.mem str tl -> StrMap.find str tl |> snd, [tl]
  | [tl] ->
    let v = MVariable.create Immut (Some str) in
    let tl = StrMap.add str (KAny, v) tl in
    v, [tl]
  | env::t when StrMap.mem str env ->
    begin match StrMap.find str env with
    | KFun, v -> v, env::t
    | KVal, _ ->
      let v, t = resolve_call str t in
      v, env::t
    | KAny, _ | KAnyOpt, _ -> raise (ScopeError ("Cannot resolve symbol "^str))
    end
  | env::t ->
    let v, t = resolve_call str t in
    v, env::t
  
let rec resolve str t =
  match t with
  | [] -> assert false
  | [tl] when StrMap.mem str tl -> StrMap.find str tl |> snd, [tl]
  | [tl] ->
    let v = MVariable.create Immut (Some str) in
    let tl = StrMap.add str (KAny, v) tl in
    v, [tl]
  | env::t when StrMap.mem str env ->
    begin match StrMap.find str env with
    | KFun, v | KVal, v | KAny, v -> v, env::t
    | KAnyOpt, _ -> raise (ScopeError ("Cannot resolve symbol "^str))
    end
  | env::t ->
    let v, t = resolve str t in
    v, env::t

let resolve_parent str t =
  match t with
  | [] -> assert false
  | env::t ->
    let v,t = resolve str t in
    v, env::t
