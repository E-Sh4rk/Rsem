open Mlsem_types
open Mlsem_common

type label = string
[@@deriving show]
type arg_label = Positional | Named of label | Ell
[@@deriving show]
type 'a arg = arg_label * 'a
[@@deriving show]

type t = Env.t * (TyScheme.t list) VarMap.t

let simplify_tl ty = ty |> TyScheme.bot_instance |> TyScheme.norm_and_simpl
let merge_tl tys =
  let tscap t1 t2 =
    let (tvs1, t1), (tvs2, t2) = TyScheme.get t1, TyScheme.get t2 in
    TyScheme.mk (MVarSet.union tvs1 tvs2) (GTy.cap t1 t2)
  in
  List.fold_left tscap (TyScheme.mk_mono GTy.any) tys |> simplify_tl

let initial = Defs.initial_env, VarMap.empty
let get_sym_sigs v senv = match VarMap.find_opt v senv with None -> [] | Some lst -> lst
let no_symlabel ty =
  let lb, ub = TyScheme.get ty |> snd |> GTy.lb, TyScheme.get ty |> snd |> GTy.ub in
  Rstt.Labels.sym_of_ty lb |> List.is_empty && Rstt.Labels.sym_of_ty ub |> List.is_empty
let add_signature v ty (env,senv) =
  let ty = simplify_tl ty in
  if TyScheme.fv ty |> MVarSet.is_empty |> not then
    failwith "Top-level definitions cannot contain monomorphic type variables." ;
  if no_symlabel ty then
    let ty = if Env.mem v env then merge_tl [Env.find v env;ty] else ty in
    Env.replace v ty env, senv
  else
    let env = if Env.mem v env then env else Env.add v (TyScheme.mk_mono GTy.any) env in
    let senv = VarMap.add v (ty :: get_sym_sigs v senv) senv in
    env, senv
let replace_signature v ty (env,senv) =
  let env, senv = Env.rm v env, VarMap.remove v senv in
  add_signature v ty (env, senv)

let mem v (env, _) = Env.mem v env
let env (env, _) = env
let get_signature v (env,senv) =
  merge_tl (Env.find v env :: get_sym_sigs v senv)

let apply_arg acc (i,(k,arg)) =
  match k, arg with
  | _, None -> acc
  | Ell, _ -> acc
  | Positional, Some arg ->
    let str = "#"^string_of_int (i+1) in
    (match Rstt.Labels.substitute str arg acc with None -> raise Exit | Some acc -> acc)
  | Named str, Some arg ->
    let str = "#"^str in
    (match Rstt.Labels.substitute str arg acc with None -> raise Exit | Some acc -> acc)
let apply_args args ty =
  args |> List.mapi (fun i a -> (i, a)) |> List.fold_left apply_arg ty
let apply_args args ty =
  try
    let tvs, gty = TyScheme.get ty in
    let gty = GTy.map (apply_args args) gty in
    let ty = TyScheme.mk tvs gty in
    if no_symlabel ty |> not then raise Exit ;
    Some ty
  with Exit -> None
let get_fun_signature v args (env, senv) =
  let ty = Env.find v env in
  let tys = List.filter_map (apply_args args) (get_sym_sigs v senv) in
  merge_tl (ty::tys)
