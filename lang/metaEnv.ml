open Mlsem_types
open Mlsem_common

type label = string
[@@deriving show]
type arg_label = Positional | Named of label | Ell
[@@deriving show]
type 'a arg = arg_label * 'a
[@@deriving show]

type builder = (Rstt.Var.t, Rstt.RowVar.t, Rstt.Builder.TId.t) Rstt.Builder.t
type funsig = (Rstt.Var.t, Rstt.RowVar.t, Rstt.Builder.TId.t) Rstt.FunSig.t

type fsig = {
  decl : funsig ;
  (* Class-overload restrictions declared for this signature, in the order they
     must be applied to its first parameter. *)
  restr : (bool * string) list ;
  build : builder -> GTy.t ;
}

type sigs = { resolved:GTy.t list ; symbolic:fsig list }
type signature = SigTy of GTy.t | SigFun of fsig
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

(* Same restriction, but performed on the (not yet built) signature. It must be
   used for the signatures whose argument is polymorphic: their identifier being
   a type variable, they cannot be destructed once built. *)
let restrict_first_param' ~present cls b =
  let open Rstt.Builder in
  let restr =
    let cty = TTy (class_ty ~present cls) in
    if present then cty else TOption cty
  in
  let restrict a =
    match a.Rstt.Arg.pos_named with
    | [] -> a
    | (name,t)::ps -> { a with pos_named=(name, TCap (t, restr))::ps }
  in
  match b with
  | TArrow (TArg a, ret) -> TArrow (TArg (restrict a), ret)
  | TArrow (TPolyArg a, ret) -> TArrow (TPolyArg (restrict a), ret)
  | b -> b

(* ===== Function signatures ===== *)

let mk_fsig build decl = { decl ; restr=[] ; build }
let is_resolved f = Rstt.FunSig.is_regular_ty f.decl
let restrict_sig ~present cls f = { f with restr=f.restr@[present,cls] }

(* Type of the instance [decl] of the signature [f]. *)
let instance_ty ?(polymorphic=false) f decl =
  Rstt.FunSig.to_regular ~polymorphic decl
  |> (fun b -> List.fold_left
    (fun b (present,cls) -> restrict_first_param' ~present cls b) b f.restr)
  |> f.build
let fsig_ty ?polymorphic f = instance_ty ?polymorphic f f.decl

let resolve_signature arg f =
  (* [specialize] fails when a label variable has no possible instantiation, and
     [instance_ty] when one could not be resolved at all. *)
  try Some (Rstt.FunSig.specialize f.decl arg |> instance_ty f)
  with Invalid_argument _ -> None

(* ===== Registration of the signatures ===== *)

let set_sigs v sigs (env,senv) =
  let senv = VarMap.add v sigs senv in
  let ty = sigs.resolved |> GTy.conj |> TyScheme.mk_poly in
  let env = Env.replace v ty env in
  env, senv

let add_signature v s (env,senv) =
  let sigs = get_sigs v senv in
  let sigs =
    match s with
    | SigTy ty -> { sigs with resolved=ty::sigs.resolved }
    | SigFun f when is_resolved f -> { sigs with resolved=(fsig_ty f)::sigs.resolved }
    | SigFun f -> { sigs with symbolic=f::sigs.symbolic }
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
  if (List.is_empty sigs.resolved && List.is_empty sigs.symbolic)
  || List.for_all is_fun_sig sigs.resolved |> not then
    failwith (Format.asprintf
      "Cannot declare a class-overload for %a: it is not a function." Variable.pp v) ;
  let sigs = { resolved=List.map (restrict_first_param ~present:false cls) sigs.resolved ;
               symbolic=List.map (restrict_sig ~present:false cls) sigs.symbolic } in
  set_sigs v sigs (env,senv)

(* Restriction to register for the method of the class [cls]: its first
   parameter is restricted to the values of class [cls]. *)
let class_overload_sig cls f = restrict_sig ~present:true cls f
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
let get_signatures v (_, senv) = VarMap.find_opt v senv
