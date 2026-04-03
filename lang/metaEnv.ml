open Mlsem_types
open Mlsem_common

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
let add_signature v ty (env,senv) =
  let ty = simplify_tl ty in
  if TyScheme.fv ty |> MVarSet.is_empty |> not then
    failwith "Top-level definitions cannot contain monomorphic type variables." ;
  let lb, ub = TyScheme.get ty |> snd |> GTy.lb, TyScheme.get ty |> snd |> GTy.ub in
  if Rstt.Labels.sym_of_ty lb |> List.is_empty &&
     Rstt.Labels.sym_of_ty ub |> List.is_empty
  then
    let ty = if Env.mem v env then merge_tl [Env.find v env;ty] else ty in
    Env.replace v ty env, senv
  else
    let env = if Env.mem v env then env else Env.add v (TyScheme.mk_mono GTy.any) env in
    let senv = VarMap.add v (ty :: get_sym_sigs v senv) senv in
    env, senv
let replace_signature v ty (env,senv) =
  let env, senv = Env.rm v env, VarMap.remove v senv in
  add_signature v ty (env, senv)

let env (env, _) = env
let get_sym_signature v (env,senv) =
  merge_tl (Env.find v env :: get_sym_sigs v senv)
