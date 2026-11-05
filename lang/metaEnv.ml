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
  restr : (bool * Rstt.Classes.cls) list ;
  build : builder -> GTy.t ;
}

(* The signatures of a function are of three kinds (cf. the interface):
   [base], [methods] (each with the class it is the class-overload for) and
   [methods_default]. [symbolic] are the signatures that still contain label
   variables, with the class of the class-overload they come from, if any. *)
type sigs = { base:GTy.t list ; methods:(string * GTy.t) list ;
              methods_default:GTy.t list ; symbolic:(string option * fsig) list }
type signature = SigTy of GTy.t | SigFun of fsig

module StrMap = Map.Make(String)
module StrSet = Set.Make(String)
(* [ns] maps a namespace and a name to the variable R code reaches with
   [ns::name]. Such a variable is never bound by the program itself: its type
   only comes from the signatures declared for it.
   [ovl] lists the declared class-overloads (generic name, class), in their
   order of declaration, and [bound] the names that have been given a type
   (whose class-overloads can thus no longer be declared). *)
type t = { env : Env.t ; senv : sigs VarMap.t ; ns : Variable.t StrMap.t StrMap.t ;
           ovl : (string * string) list ; bound : StrSet.t }

let simplify_tl ty =
  let tvs, ty = ty |> TyScheme.bot_instance |> TyScheme.get in
  let ty = GTy.map Rstt.TyOp.simplify ty |> GTy.factorize in
  TyScheme.mk tvs ty

let initial = { env=Defs.initial_env ; senv=VarMap.empty ; ns=StrMap.empty ;
                ovl=[] ; bound=StrSet.empty }
let get_sigs v senv =
  match VarMap.find_opt v senv with
  | None -> { base=[] ; methods=[] ; methods_default=[] ; symbolic=[] }
  | Some s -> s

(* ===== S3 dispatch (class overloads) ===== *)

let fun_ty = Arrow.any |> Rstt.Attr.mk_content
let is_fun_sig ty =
  let ty = GTy.ub ty in
  Ty.leq ty fun_ty && Ty.is_empty ty |> not

(* A restriction of the classes of a value is a list of [(present, cls)], each
   saying whether it has the class [cls] or not (as the [restr] of a [fsig]).
   [class_ty restr] is the type of the values [restr] admits, e.g.
   [<c1, ~c2, ...>] for [[true,c1 ; false,c2]]. It is a single class atom:
   intersecting one atom per class instead makes the intersections of the
   signatures exponentially slower, as rstt does not merge them. *)
let class_ty restr =
  let open Rstt in
  let pos, neg = List.partition fst restr in
  let pos = pos |> List.map (fun (_,cls) -> Classes.L (cls, [])) in
  let neg = neg |> List.map snd in
  let classes = Classes.mk { pos ; neg ; unk=[] ; tail=Classes.Unknown } in
  Attr.mk { content=Ty.any ; classes ; attrs=Ty.any }

(* The parameter a restriction applies to may be absent, unless the
   restriction requires a class. *)
let is_required restr = List.exists fst restr

(* [restrict_first_param restr ty] intersects the type of the first parameter
   (if any) of every arrow of the function signature [ty] with the values
   [restr] admits (cf. [class_ty]), or that are absent if [restr] requires no
   class. Non-functional types are returned unchanged. *)
let restrict_first_param restr ty =
  let open Rstt in
  if restr = [] || is_fun_sig ty |> not then ty else
  let restr =
    let cty = class_ty restr in
    (if is_required restr then Ty.O.required cty else Ty.O.optional cty) |> Ty.F.mk_descr
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
let restrict_first_param' restr b =
  let open Rstt.Builder in
  if restr = [] then b else
  let restr =
    let cty = TTy (class_ty restr) in
    if is_required restr then cty else TOption cty
  in
  let restrict a =
    match a.Rstt.Arg.pos_named with
    | [] -> a
    | (name,t)::ps -> { a with pos_named=(name, TCap (t, restr))::ps }
  in
  (* A signature is an intersection of arrows (cf. [Rstt.FunSig.to_regular]). *)
  let rec aux b =
    match b with
    | TArrow (TArg a, ret) -> TArrow (TArg (restrict a), ret)
    | TArrow (TPolyArg a, ret) -> TArrow (TPolyArg (restrict a), ret)
    | TCap (b1, b2) -> TCap (aux b1, aux b2)
    | b -> b
  in
  aux b

(* ===== Function signatures ===== *)

let mk_fsig build decl = { decl ; restr=[] ; build }
let is_resolved f = Rstt.FunSig.is_regular_ty f.decl
let restrict_sig restr f = { f with restr=f.restr@restr }
let arrows f = f.decl |> List.map (fun a -> { f with decl=[a] })

(* Type of the instance [decl] of the signature [f]. A restriction intersects
   the class atom of the first parameter with another one: the result is
   simplified to merge them, as intersecting signatures whose parameters have
   several class atoms is exponentially slower (cf. [class_ty]). *)
let instance_ty ?(polymorphic=false) f decl =
  Rstt.FunSig.to_regular ~polymorphic decl
  |> restrict_first_param' f.restr
  |> f.build
  |> if f.restr = [] then Fun.id else GTy.map Rstt.TyOp.simplify
let fsig_ty ?polymorphic f = instance_ty ?polymorphic f f.decl

let resolve_signature arg f =
  (* [specialize] fails when a label variable has no possible instantiation, and
     [instance_ty] when one could not be resolved at all. *)
  try Some (Rstt.FunSig.specialize f.decl arg |> instance_ty f)
  with Invalid_argument _ -> None

(* ===== Class-overloads ===== *)

(* Classes already declared to rstt. As rstt, it is global: a class can only be
   declared once, with all the methods it implements. *)
let declared = Hashtbl.create 10

(* The name R gives to the generic Rsem names [m]: the subset operators are
   named after their syntax (cf. [PAst]), e.g. [[]] for R's [\[]. *)
let r_name m =
  match m with
  | "[]" -> "[" | "[[]]" -> "[[" | "[]<-" -> "[<-" | "[[]]<-" -> "[[<-"
  | m -> m

(* Declares the class-overload of the generic [m] for the class [cls]: [cls]
   will implement the method class of [m] (named after [r_name m]). The methods
   of a class and the restrictions of the signatures are derived from the
   class-overloads, so they must all be declared before the class is declared
   (i.e. before any type mentions it, cf. [declare_classes]) and before [m] is
   given a type. Declaring the same class-overload again does nothing. *)
let new_class_overload m cls t =
  if List.mem (m,cls) t.ovl then t
  else begin
    let error reason =
      failwith (Printf.sprintf "Cannot declare the class-overload %s @ %s: %s." m cls reason) in
    if StrSet.mem m t.bound then error (m^" has already been given a type") ;
    if Hashtbl.mem declared cls then
      error (cls^" has already been declared (class-overloads must precede any type mentioning their class)") ;
    { t with ovl=t.ovl@[m,cls] }
  end

(* Declares to rstt the classes of the class-overloads that have not been
   declared yet, each with the methods of all its class-overloads. It must be
   called before any type mentioning these classes is built. *)
let declare_classes t =
  t.ovl |> List.iter (fun (_,cls) ->
    if Hashtbl.mem declared cls |> not then begin
      let methods = t.ovl |> List.filter_map (fun (m,c) ->
        if String.equal c cls then Some (r_name m) else None) in
      begin try Rstt.Classes.declare_class cls ~methods
      with Invalid_argument _ ->
        failwith (Printf.sprintf
          "Cannot declare the class %s: it is mentioned by a type built before its class-overloads." cls)
      end ;
      Hashtbl.add declared cls ()
    end)

(* Classes of the class-overloads of the generic [m], in their order of
   declaration, and those declared after the class-overload for [cls].
   Class-overloads are matched with the generics by name only, as the method
   classes are: those of two distinct generics with the same name (e.g. a
   global one and the one of a namespace) are mixed together.
   TODO: improve *)
let overloads m t =
  t.ovl |> List.filter_map (fun (m',c) -> if String.equal m m' then Some c else None)
let overloads_after cls m t =
  let rec after clss =
    match clss with
    | [] -> []
    | c::clss when String.equal c cls -> clss
    | _::clss -> after clss
  in
  after (overloads m t)
let is_method m t = overloads m t <> []

(* The method class of the generic [m], i.e. the class of the values whose
   class has a class-overload of [m]. *)
let method_class m = Rstt.Classes.Method (r_name m)

(* The restriction of the first parameter of a signature of the generic [m]
   (cf. [add_signature]): the values whose class has no class-overload of [m]
   (i.e. [<~@m, ...>]) for a base signature, and those whose class has no
   class-overload of [m] declared after the one for [cls] for the signature of
   that class-overload (whose first parameter is already restricted to [cls],
   cf. [class_overload_sig]). *)
let restriction ?cls m t =
  match cls with
  | None when is_method m t -> [false, method_class m]
  | None -> []
  | Some cls -> overloads_after cls m t |> List.map (fun c -> false, Rstt.Classes.Class c)

(* The default signature of the methods of the generic [m],
   [(X: <@m, ...>, ...: any) -> any]: it covers the values for which the
   base signatures do not apply, i.e. the complement [<@m, ...>] of their
   restriction [<~@m, ...>] (a class implies the method classes it
   implements). Contrarily to the signatures of the methods, it also covers
   the values of these classes whose other classes are unknown. *)
let methods_default_ty m =
  let open Rstt in
  let field ty = Ty.F.mk_descr (Ty.O.required ty) in
  let x = class_ty [true, method_class m] in
  let dom = Arg.mk { pos_named=["X", field x] ;
                     pos_tl=field Ty.any ; named=[] ; named_tl=field Ty.any } in
  Arrow.mk dom Ty.any |> Attr.mk_content |> GTy.mk

(* Restrictions of the signature of the class-overload of a generic for the
   class [cls]: its first parameter is restricted to the values of class
   [cls]. *)
let class_overload_sig cls f = restrict_sig [true, Rstt.Classes.Class cls] f
let class_overload_ty cls ty = restrict_first_param [true, Rstt.Classes.Class cls] ty

(* ===== Registration of the signatures ===== *)

(* The type of a variable is the intersection of its resolved signatures. It
   is computed incrementally, by intersecting the previous one with each new
   signature, and is not simplified: recomputing or simplifying the
   intersection of the many signatures of a generic with class-overloads
   (e.g. [+]) at each signature added is expensive. The applications of the
   variable use its signatures rather than this type anyway (cf.
   [Transform]), and [get] simplifies it for printing. *)
let add_resolved v ty t =
  let ty =
    if VarMap.mem v t.senv
    then GTy.conj [ Env.find v t.env |> TyScheme.get |> snd ; ty ]
    else ty
  in
  Env.replace v (TyScheme.mk_poly ty) t.env

(* The first parameter of a signature of [name] is restricted as described by
   [restriction]. *)
let add_signature ?cls ~name v s t =
  let restr = restriction ?cls name t in
  let s =
    match s with
    | SigTy ty -> SigTy (restrict_first_param restr ty)
    | SigFun f -> SigFun (restrict_sig restr f)
  in
  let t = { t with bound=StrSet.add name t.bound } in
  let sigs = get_sigs v t.senv in
  let add ty sigs =
    match cls with
    | None -> { sigs with base=ty::sigs.base }
    | Some cls -> { sigs with methods=(cls,ty)::sigs.methods }
  in
  let resolved, sigs =
    match s with
    | SigTy ty -> Some ty, add ty sigs
    | SigFun f when is_resolved f -> let ty = fsig_ty f in Some ty, add ty sigs
    | SigFun f -> None, { sigs with symbolic=(cls,f)::sigs.symbolic }
  in
  let sigs =
    if is_method name t && sigs.methods_default = []
    then { sigs with methods_default=[methods_default_ty name] }
    else sigs
  in
  let env =
    match resolved with
    | Some ty -> add_resolved v ty t
    | None when VarMap.mem v t.senv -> t.env
    | None -> Env.replace v (TyScheme.mk_poly GTy.any) t.env
  in
  { t with env ; senv=VarMap.add v sigs t.senv }

(* An inferred type is restricted as a signature would be. *)
let set_from_tyscheme v ts t =
  if TyScheme.fv ts |> MVarSet.is_empty |> not then
    failwith "Top-level definitions cannot contain monomorphic type variables." ;
  let ts, t =
    match Variable.get_name v with
    | None -> ts, t
    | Some name ->
      let t = { t with bound=StrSet.add name t.bound } in
      match restriction name t with
      | [] -> ts, t
      | restr ->
        let tvs, ty = TyScheme.get ts in
        TyScheme.mk tvs (restrict_first_param restr ty), t
  in
  let ts = simplify_tl ts in
  let env, senv = Env.rm v t.env, VarMap.remove v t.senv in
  { t with env=Env.add v ts env ; senv }

let mem v t = Env.mem v t.env
let env t = t.env
let get v t =
  let ts = Env.find v t.env in
  if VarMap.mem v t.senv then simplify_tl ts else ts
let get_signatures v t = VarMap.find_opt v t.senv

let base sigs = sigs.base
let methods ?cls sigs =
  sigs.methods |> List.filter_map (fun (c,ty) ->
    match cls with
    | Some cls when String.equal c cls |> not -> None
    | _ -> Some ty)
let methods_with_class sigs = sigs.methods
let methods_default sigs = sigs.methods_default
let symbolic sigs = sigs.symbolic
let all sigs = sigs.base@(List.map snd sigs.methods)@sigs.methods_default

(* ===== Namespaces ===== *)

let ns_find ns name t =
  StrMap.find_opt ns t.ns |> Option.map (StrMap.find_opt name) |> Option.join

(* The successive signatures of a same name are its overloads: contrarily to a
   top-level name, a namespaced one is never redefined by the program, so a new
   signature cannot be shadowing the previous ones. *)
let ns_add_signature ns name s t =
  let v, t =
    match ns_find ns name t with
    | Some v -> v, t
    | None ->
      let v = Mlsem.Lang.MVariable.create Immut (Some (ns^"::"^name)) in
      let names = StrMap.find_opt ns t.ns |> Option.value ~default:StrMap.empty in
      v, { t with ns=StrMap.add ns (StrMap.add name v names) t.ns }
  in
  add_signature ~name v s t

(* The packages R attaches by default, in the order of its search path. *)
let search_path = ["stats"; "graphics"; "grDevices"; "utils"; "datasets"; "methods"; "base"]

let search name t = List.find_map (fun ns -> ns_find ns name t) search_path
