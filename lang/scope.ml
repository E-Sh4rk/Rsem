open Mlsem.Common
open Mlsem.Types
module MVariable = Mlsem.Lang.MVariable
module StrMap = Map.Make(String)

(* [KParam] is a parameter: of any kind too, but bound from the start of the
   function's body, unlike its other local names, bound when assigned. *)
type kind = KFun | KVal | KAny | KParam | KAnyOpt
type env = (kind * Variable.t) StrMap.t
(* [envs] are the nested scopes, innermost first and top level last. [tenv]
   gives the namespaces a name the top level does not bind is searched for. *)
type t = { envs : env list ; tenv : MetaEnv.t }

exception ScopeError of string

let fun_ty = Arrow.any |> Rstt.Attr.mk_content
let from_toplevel tenv idmap =
  let tl = idmap |> StrMap.map (fun v ->
    if MetaEnv.mem v tenv
    then
      let ty = MetaEnv.get v tenv |> TyScheme.get |> snd |> GTy.ub in
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
    let k = StrMap.find str env |> fst in
    (* A parameter the body assigns stays a parameter. *)
    if k <> kind && not (k = KParam && kind = KAny)
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
      | Some ((KFun | KAny | KParam), v) -> v
      | Some (KAnyOpt, _) -> raise (ScopeError ("Cannot resolve symbol "^str))
      end
  in
  aux t.envs

(* The variables a call of [str] may refer to, innermost first. As in R,
   the bindings known not to be functions are skipped, and the search goes on
   past the parameters, which may or may not be functions: it ends with the
   first other binding, the top-level one, or the namespaces past the top
   level. Not past the other local names: one may be called before the body
   assigns it, where it is not bound yet, and Rsem cannot tell. The call is
   to the first of them that is a function at run time (cf. [PAst]). A
   single variable, [resolve_call]'s, when no parameter is followed by
   another binding. *)
let call_candidates str t =
  let rec aux = function
    | [] -> []
    | [ tl ] ->
      begin match StrMap.find_opt str tl with
      | None | Some (KVal, _) ->
        begin match Defs.BuiltinOp.find_builtin str with
        | Some v -> [ v ]
        | None -> Option.to_list (MetaEnv.search str t.tenv)
        end
      | Some ((KFun | KAny | KParam), v) -> [ v ]
      | Some (KAnyOpt, _) -> raise (ScopeError ("Cannot resolve symbol "^str))
      end
    | env::envs ->
      begin match StrMap.find_opt str env with
      | None | Some (KVal, _) -> aux envs
      | Some ((KFun | KAny), v) -> [ v ]
      | Some (KParam, v) -> v :: aux envs
      | Some (KAnyOpt, _) -> raise (ScopeError ("Cannot resolve symbol "^str))
      end
  in
  match aux t.envs with
  | [] | [ _ ] -> [ resolve_call str t ]
  | vs -> vs

let resolve ?search str t =
  let rec aux envs =
    match envs with
    | [] -> unresolved ?search str t
    | env::envs ->
      begin match StrMap.find_opt str env with
      | None -> aux envs
      | Some ((KFun | KVal | KAny | KParam), v) -> v
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
