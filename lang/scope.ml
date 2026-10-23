open Mlsem.Common
open Mlsem.Types
module MVariable = Mlsem.Lang.MVariable
module StrMap = Map.Make(String)

type kind = KFun | KVal | KAny | KAnyOpt
type env = (kind * Variable.t) StrMap.t
(* [envs] are the nested scopes, innermost first and top level last. [tenv]
   gives the namespaces a name the top level does not bind is searched for. *)
type t = { envs : env list ; tenv : MetaEnv.t }

exception ScopeError of string

let fun_ty = Arrow.any |> Rstt.Attr.mk_content
let from_toplevel tenv idmap =
  let env = MetaEnv.env tenv in
  let tl = idmap |> StrMap.map (fun v ->
    if Env.mem v env
    then
      let ty = Env.find v env |> TyScheme.get |> snd |> GTy.ub in
      if Ty.leq ty fun_ty then KFun, v
      else if Ty.leq ty (Ty.neg fun_ty) then KVal, v
      else KAny, v
    else KAny, v
    ) in
  { envs=[ tl ] ; tenv }

let new_scope t = { t with envs=StrMap.empty::t.envs }

(* Whether [str] is bound anywhere in [t]. *)
let is_bound str t = List.exists (StrMap.mem str) t.envs
(* [annot] is the type the user has annotated [str] with, if any (cf. the
   [#| fun/var : t] declarations). *)
let add_local_binding ?annot str kind t =
  match t.envs with
  | [] -> assert false
  | env::_ when StrMap.mem str env ->
    if (StrMap.find str env |> fst) <> kind
    then raise (ScopeError ("Symbol "^str^" already defined with different kind"))
    else t
  | env::envs ->
    let mkind = match annot with
      | None -> MVariable.Mut
      | Some gty -> MVariable.AnnotMut gty
    in
    let v = MVariable.create mkind (Some str) in
    let env = StrMap.add str (kind,v) env in
    { t with envs=env::envs }

(* A name no definition binds is looked up as R does past the global
   environment: in the namespaces of the search path, ending with [base].
   Unless [search] is false: an assignment never reaches past the global
   environment, so [paste <- ...] defines a global [paste] instead of
   redefining [base::paste]. *)
let unresolved ?(search=true) str t =
  match Defs.BuiltinOp.find_builtin str with
  | Some v -> v
  | None ->
    match if search then MetaEnv.search str t.tenv else None with
    | Some v -> v
    | None -> MVariable.create Immut (Some str)

(* [ns::name] does not depend on the scope: a name no signature has been
   declared for is unbound, just like an unknown top-level name. *)
let resolve_ns ns name t =
  match MetaEnv.ns_find ns name t.tenv with
  | Some v -> v
  | None -> MVariable.create Immut (Some (ns^"::"^name))

(* The variable [str] refers to when it is called: as in R, the bindings known
   not to be functions are skipped. Only the top-level ones can be known as
   such, the local ones being of any kind. *)
let resolve_call str t =
  let rec aux envs =
    match envs with
    | [] -> unresolved str t
    | env::envs ->
      begin match StrMap.find_opt str env with
      | None | Some (KVal, _) -> aux envs
      | Some ((KFun | KAny), v) -> v
      | Some (KAnyOpt, _) -> raise (ScopeError ("Cannot resolve symbol "^str))
      end
  in
  aux t.envs

let resolve ?search str t =
  let rec aux envs =
    match envs with
    | [] -> unresolved ?search str t
    | env::envs ->
      begin match StrMap.find_opt str env with
      | None -> aux envs
      | Some ((KFun | KVal | KAny), v) -> v
      | Some (KAnyOpt, _) -> raise (ScopeError ("Cannot resolve symbol "^str))
      end
  in
  aux t.envs

(* The variable an assignment to [str] defines. *)
let resolve_assigned str t = resolve ~search:false str t

let resolve_parent str t =
  match t.envs with
  | [] -> assert false
  | _::envs -> resolve_assigned str { t with envs }
