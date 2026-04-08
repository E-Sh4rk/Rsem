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
  let open Rstt.Labels in
  let lb, ub = TyScheme.get ty |> snd |> GTy.lb, TyScheme.get ty |> snd |> GTy.ub in
  sym_of_ty lb |> Set.is_empty && sym_of_ty ub |> Set.is_empty

let add_sym_aliases ty =
  let open Sstt in
  let pos_aliases = Hashtbl.create 16 in
  let named_aliases = Hashtbl.create 16 in
  let _ = Ty.nodes ty |> List.iter (fun n ->
    Rstt.Arg.ids_of n |> List.iter (fun id ->
      let { Rstt.Arg.pos ; pos_named ; _ } = Rstt.Arg.params_of_id id in
      let n = List.length pos in
      pos_named |> List.iteri (fun i (str,()) ->
        Hashtbl.add pos_aliases (n+i) str ;
        Hashtbl.add named_aliases str (n+i) ;)
      )
    ) in
  let pos =
    Hashtbl.to_seq_keys pos_aliases |> List.of_seq |> List.sort_uniq Int.compare
    |> List.map (fun pos ->
        let aliases = Hashtbl.find_all pos_aliases pos
        |> List.sort_uniq String.compare
        |> List.map (fun alias -> Rstt.Labels.Named alias)
        in
        { Rstt.Labels.sym=Pos pos ; target=Sym (Pos pos::aliases) }
      )
  in
  let named =
    Hashtbl.to_seq_keys named_aliases |> List.of_seq |> List.sort_uniq String.compare
    |> List.map (fun named ->
        let aliases = Hashtbl.find_all named_aliases named
        |> List.sort_uniq Int.compare
        |> List.map (fun alias -> Rstt.Labels.Pos alias)
        in
        { Rstt.Labels.sym=Named named ; target=Sym (Named named::aliases) }
      )
  in
  Rstt.Labels.substitute (pos@named) ty 

let add_signature v ty (env,senv) =
  let ty = simplify_tl ty in
  if TyScheme.fv ty |> MVarSet.is_empty |> not then
    failwith "Top-level definitions cannot contain monomorphic type variables." ;
  if no_symlabel ty then
    let ty = if Env.mem v env then merge_tl [Env.find v env;ty] else ty in
    Env.replace v ty env, senv
  else
    let env = if Env.mem v env then env else Env.add v (TyScheme.mk_mono GTy.any) env in
    let tvs, gty = TyScheme.get ty in
    let gty = GTy.map add_sym_aliases gty in
    let ty = TyScheme.mk tvs gty in
    let senv = VarMap.add v (ty :: get_sym_sigs v senv) senv in
    env, senv
let replace_signature v ty (env,senv) =
  let env, senv = Env.rm v env, VarMap.remove v senv in
  add_signature v ty (env, senv)

let mem v (env, _) = Env.mem v env
let env (env, _) = env
let get_signature v (env,senv) =
  merge_tl (Env.find v env :: get_sym_sigs v senv)

let arg_to_subst (i,(k,arg)) =
  match k, arg with
  | _, None -> None
  | Ell, _ -> None
  | Positional, Some arg -> Some {Rstt.Labels.sym=(Pos i) ; target=arg}
  | Named str, Some arg -> Some {Rstt.Labels.sym=(Named str) ; target=arg}
let apply_args args ty =
  let subst = args |> List.mapi (fun i a -> (i, a)) |> List.filter_map arg_to_subst in
  Rstt.Labels.substitute subst ty
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
