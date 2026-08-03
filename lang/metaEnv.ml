open Mlsem_types
open Mlsem_common

type label = string
[@@deriving show]
type arg_label = Positional | Named of label | Ell
[@@deriving show]
type 'a arg = arg_label * 'a
[@@deriving show]

type sigs = { resolved:GTy.t list ; symbolic:GTy.t list }
type t = Env.t * sigs VarMap.t

let simplify_tl ty =
  let tvs, ty = ty |> TyScheme.bot_instance |> TyScheme.get in
  let ty = GTy.map Rstt.TyOp.simplify ty |> GTy.factorize in
  TyScheme.mk tvs ty

let initial = Defs.initial_env, VarMap.empty
let get_sigs v senv =
  match VarMap.find_opt v senv with
  | None -> { resolved=[] ; symbolic=[] }
  | Some s -> s
let no_symlabel ty =
  let open Rstt.Labels in
  let lb, ub = GTy.lb ty, GTy.ub ty in
  sym_of_ty lb |> List.is_empty && sym_of_ty ub |> List.is_empty

let add_signature v ty (env,senv) =
  let sigs = get_sigs v senv in
  let sigs =
    if no_symlabel ty
    then { sigs with resolved=ty::sigs.resolved }
    else { sigs with symbolic=ty::sigs.symbolic }
  in
  let senv = VarMap.add v sigs senv in
  let ty = sigs.resolved |> GTy.conj |> TyScheme.mk_poly in
  let env = Env.replace v ty env in
  env, senv

let set_from_tyscheme v ts (env,senv) =
  if TyScheme.fv ts |> MVarSet.is_empty |> not then
    failwith "Top-level definitions cannot contain monomorphic type variables." ;
  let ts = simplify_tl ts in
  let env, senv = Env.rm v env, VarMap.remove v senv in
  Env.add v ts env, senv

let mem v (env, _) = Env.mem v env
let env (env, _) = env
let get v (env,_) = Env.find v env

let arg_to_subst (i,(k,arg)) =
  match k, arg with
  | _, None -> None
  | Ell, _ -> None
  | Positional, Some arg -> Some {Rstt.Labels.selector=(SelectLabel (Pos i)) ; target=arg}
  | Named str, Some arg -> Some {Rstt.Labels.selector=(SelectLabel (Named str)) ; target=arg}
let apply_args args ty =
  let subst = args |> List.mapi (fun i a -> (i, a)) |> List.filter_map arg_to_subst in
  Rstt.Labels.substitute subst ty
let get_signatures v (_, senv) = VarMap.find_opt v senv

let resolve_signature args gty =
  try
    let gty = GTy.map (apply_args args) gty in
    if no_symlabel gty |> not then raise Exit ;
    Some gty
  with Exit -> None
