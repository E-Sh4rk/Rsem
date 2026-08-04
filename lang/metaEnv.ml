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

(* ===== S3 dispatch (class overloads) ===== *)

let fun_ty = Arrow.any |> Rstt.Attr.mk_content
let is_fun_sig ty =
  let ty = GTy.ub ty in
  Ty.leq ty fun_ty && Ty.is_empty ty |> not

(* [<cls, ...>] if [present], [<~cls, ...>] otherwise. *)
let class_ty ~present cls =
  let open Rstt in
  let line = Classes.L (cls, []) in
  let classes =
    if present
    then Classes.mk { pos=[line] ; neg=[] ; unk=[] ; tail=Classes.Unknown }
    else Classes.mk { pos=[] ; neg=[line] ; unk=[] ; tail=Classes.Unknown }
  in
  Attr.mk { content=Ty.any ; classes ; attrs=Ty.any }

(* [restrict_first_param ~present cls ty] intersects the type of the first
   parameter (if any) of every arrow of the function signature [ty] with
   [<cls, ...>] if [present], and with [<~cls, ...>?] otherwise.
   Non-functional types are returned unchanged. *)
let restrict_first_param ~present cls ty =
  let open Rstt in
  if is_fun_sig ty |> not then ty else
  let restr =
    let cty = class_ty ~present cls in
    (if present then Ty.O.required cty else Ty.O.optional cty) |> Ty.F.mk_descr
  in
  let restrict_field fty = Ty.F.cap fty restr in
  let restrict_dom dom =
    Arg.destruct dom |> List.map (function
      | Arg.DefSite ({ pos_named=(name,fty)::ps ; _ } as a) ->
        Arg.mk { a with pos_named=(name, restrict_field fty)::ps }
      | Arg.CallSite ({ pos'=fty::ps ; _ } as a) ->
        Arg.mk' { a with pos'=(restrict_field fty)::ps }
      | Arg.DefSite a -> Arg.mk a
      | Arg.CallSite a -> Arg.mk' a
    ) |> Ty.disj
  in
  let restrict_arrows ty =
    if Ty.leq ty Arrow.any && Ty.is_empty ty |> not
    then
      Arrow.dnf ty
      |> List.map (List.map (fun (dom,codom) -> restrict_dom dom, codom))
      |> Arrow.of_dnf
    else ty
  in
  let restrict_atom a =
    { a with Attr.content=restrict_arrows a.Attr.content }
  in
  let restrict ty =
    Attr.destruct ty
    |> List.map (fun (ps,ns) -> List.map restrict_atom ps, ns)
    |> List.map Attr.mk_line |> Ty.disj
  in
  GTy.map restrict ty

let set_sigs v sigs (env,senv) =
  let senv = VarMap.add v sigs senv in
  let ty = sigs.resolved |> GTy.conj |> TyScheme.mk_poly in
  let env = Env.replace v ty env in
  env, senv

let add_signature v ty (env,senv) =
  let sigs = get_sigs v senv in
  let sigs =
    if no_symlabel ty
    then { sigs with resolved=ty::sigs.resolved }
    else { sigs with symbolic=ty::sigs.symbolic }
  in
  set_sigs v sigs (env,senv)

(* Declares a new class-overload for the generic [v]: every signature already
   registered for [v] only applies when its first parameter is not of class
   [cls] (so that the overloads added later for [cls] take precedence). *)
let new_class_overload v cls (env,senv) =
  let sigs =
    match VarMap.find_opt v senv with
    | Some sigs -> sigs
    (* [v] has no registered signature: its type has been inferred, so we turn
       it into the initial overload instead of dropping it. *)
    | None ->
      match Env.find_opt v env |> Option.map (fun ts -> TyScheme.get ts |> snd) with
      | Some ty -> { resolved=[ty] ; symbolic=[] }
      | None -> { resolved=[] ; symbolic=[] }
  in
  let all = sigs.resolved@sigs.symbolic in
  if List.is_empty all || List.for_all is_fun_sig all |> not then
    failwith (Format.asprintf
      "Cannot declare a class-overload for %a: it is not a function." Variable.pp v) ;
  let restrict = restrict_first_param ~present:false cls in
  let sigs = { resolved=List.map restrict sigs.resolved ;
               symbolic=List.map restrict sigs.symbolic } in
  set_sigs v sigs (env,senv)

(* Type of the overload to register for the method of class [cls]:
   its first parameter is restricted to the values of class [cls]. *)
let class_overload_ty cls ty = restrict_first_param ~present:true cls ty

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
