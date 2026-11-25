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

(* The signatures of a function (cf. the interface): the [regular] ones and the
   [symbolic] ones (that still contain label variables), each with its origin,
   and the [fallback] one. [generic] is the name of the variable if it is a method
   (cf. [new_method]). *)
type origin = Base | Default | Overload of string
type kind = KFun | KVal | KAny
(* A name, with its namespace ([None] for a global name). *)
type name = string option * string
(* [kind] is the kind of the type of the variable (cf. [sigs_kind]). *)
type sigs = { regular:(origin * GTy.t) list ; symbolic:(origin * fsig) list ;
              fallback:GTy.t list ; generic:name option ; kind:kind }
type signature = SigTy of GTy.t | SigFun of fsig

module StrMap = Map.Make(String)
module Name = struct type t = name let compare = Stdlib.compare end
module NameMap = Map.Make(Name)
module NameSet = Set.Make(Name)
let string_of_name (ns, str) =
  match ns with
  | None -> str
  | Some ns -> ns^"::"^str
(* [ns] maps a namespace and a name to the variable R code reaches with
   [ns::name]. Such a variable is never bound by the program itself: its type
   only comes from the signatures declared for it. [imports] maps the names the
   package being typed imports to the namespace they come from (cf. [ns_import]).
   [meths] maps the names of the declared methods to their return type, if one
   has been declared (cf. [new_method]), and [ovl] lists their declared
   class-overloads (generic name, class), in their order of declaration. [bound]
   are the names that have been given a type (which can thus no longer be
   declared as methods, nor get new class-overloads).
   [types] maps each variable to its type, simplified. It is lazy, so that
   only the types that are used (cf. [env]) get simplified, each only once:
   simplifying the intersection of the many signatures of a generic with
   class-overloads (e.g. [+]) is expensive.
   [kinds] maps each variable to whether its type is known to be a function or
   a non-function: it is kept apart, so that it can be known without forcing
   the type (cf. [sigs_kind]). *)
type t = { types : TyScheme.t Lazy.t VarMap.t ; kinds : kind Lazy.t VarMap.t ;
           senv : sigs VarMap.t ;
           ns : Variable.t StrMap.t StrMap.t ; self : string option ;
           imports : string StrMap.t ;
           meths : GTy.t Lazy.t option NameMap.t ;
           ovl : (name * string) list ; bound : NameSet.t }

let simplify_tl ty =
  let tvs, ty = ty |> TyScheme.bot_instance |> TyScheme.get in
  let ty = GTy.map Rstt.TyOp.simplify ty |> GTy.factorize in
  TyScheme.mk tvs ty

let fun_ty = Arrow.any |> Rstt.Attr.mk_content
let kind_of_ty ty =
  let ty = GTy.ub ty in
  if Ty.leq ty fun_ty then KFun
  else if Ty.leq ty (Ty.neg fun_ty) then KVal
  else KAny
let kind_of_tyscheme ts = TyScheme.get ts |> snd |> kind_of_ty

let initial =
  let types, kinds = Env.bindings Defs.initial_env |> List.fold_left
      (fun (types, kinds) (v,ts) ->
        VarMap.add v (Lazy.from_val ts) types,
        VarMap.add v (lazy (kind_of_tyscheme ts)) kinds)
      (VarMap.empty, VarMap.empty) in
  { types ; kinds ; senv=VarMap.empty ; ns=StrMap.empty ; self=None ;
    imports=StrMap.empty ; meths=NameMap.empty ; ovl=[] ; bound=NameSet.empty }
let no_sigs = { regular=[] ; symbolic=[] ; fallback=[] ; generic=None ; kind=KAny }
(* The signatures of [v]. If none has been declared but a function type has been
   inferred for [v], this type (already restricted, cf. [set_from_tyscheme]) is
   its base signature. *)
let get_sigs v t =
  match VarMap.find_opt v t.senv with
  | Some s -> s
  | None ->
    match VarMap.find_opt v t.types, VarMap.find_opt v t.kinds with
    | Some ts, Some (lazy KFun) ->
      { no_sigs with regular=[Base, Lazy.force ts |> TyScheme.get |> snd] ; kind=KFun }
    | _ -> no_sigs
let base sigs =
  sigs.regular |> List.filter_map (fun (o,ty) -> if o = Base then Some ty else None)
let defaults sigs =
  sigs.regular |> List.filter_map (fun (o,ty) -> if o = Default then Some ty else None)
let overloads_with_class sigs =
  sigs.regular |> List.filter_map (function (Overload cls, ty) -> Some (cls,ty) | _ -> None)

(* ===== S3 dispatch (class overloads) ===== *)
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

(* The values that are not attributed (e.g. [NULL]) have no class: they never
   dispatch to a class-overload, and are admitted by any restriction that
   requires no class. *)
let unattributed = Rstt.Ty.neg Rstt.Attr.any

(* [restrict_first_param restr ty] intersects the type of the first parameter
   (if any) of every arrow of the function signature [ty] with the values
   [restr] admits (cf. [class_ty]), or that are absent if [restr] requires no
   class. Non-functional types are returned unchanged. *)
let restrict_first_param restr ty =
  let open Rstt in
  if restr = [] || is_fun_sig ty |> not then ty else
  let restr =
    let cty = class_ty restr in
    (if is_required restr then Ty.O.required cty
     else Ty.O.optional (Ty.cup cty unattributed)) |> Ty.F.mk_descr
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
    if is_required restr then cty else TOption (TCup (cty, TTy unattributed))
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

let is_fun s =
  match s with
  | SigFun _ -> true
  | SigTy ty -> is_fun_sig ty

let resolve_signature arg f =
  (* [specialize] fails when a label variable has no possible instantiation, and
     [instance_ty] when one could not be resolved at all. *)
  try Some (Rstt.FunSig.specialize f.decl arg |> instance_ty f)
  with Invalid_argument _ -> None

(* ===== Methods and class-overloads ===== *)

(* Classes already declared to rstt. As rstt, it is global: a class can only be
   declared once, with all the methods it implements. *)
let declared = Hashtbl.create 10

(* The name R gives to the generic Rsem names [m]: the subset operators are
   named after their syntax (cf. [PAst]), e.g. [[]] for R's [\[]. *)
let r_name m =
  match m with
  | "[]" -> "[" | "[[]]" -> "[[" | "[]<-" -> "[<-" | "[[]]<-" -> "[[<-"
  | m -> m

(* The packages R attaches by default, in the order of its search path. *)
let search_path = ["stats"; "graphics"; "grDevices"; "utils"; "datasets"; "methods"; "base"]

(* The names of the package being typed (cf. [set_self]) are the global ones. *)
let normalize (ns, str) t =
  match ns with
  | Some _ when ns = t.self -> None, str
  | _ -> ns, str

let is_method m t = NameMap.mem m t.meths
(* The declared method that [m] refers to, if any: [m] itself, or else the one
   the package being typed imports or the one of the search path (as in
   [search], but among the methods: they may not have a signature yet). *)
let find_method m t =
  let (_, str) as m = normalize m t in
  let others = match StrMap.find_opt str t.imports with
    | Some ns -> [ns]
    | None -> search_path
  in
  m::List.map (fun ns -> Some ns, str) others
  |> List.find_opt (fun m -> is_method m t)
(* The return type declared for the method [m], if any. *)
let return_ty m t =
  NameMap.find_opt m t.meths |> Option.join |> Option.map Lazy.force

(* Declares to rstt the classes of the class-overloads that have not been
   declared yet, each with the methods of all its class-overloads. It must be
   called before any type mentioning these classes is built. *)
let declare_classes t =
  t.ovl |> List.iter (fun (_,cls) ->
    if Hashtbl.mem declared cls |> not then begin
      let methods = t.ovl |> List.filter_map (fun ((_,m),c) ->
        if String.equal c cls then Some (r_name m) else None)
        |> List.sort_uniq String.compare in
      begin try Rstt.Classes.declare_class cls ~methods
      with Invalid_argument _ ->
        failwith (Printf.sprintf
          "Cannot declare the class %s: it is mentioned by a type built before its class-overloads." cls)
      end ;
      Hashtbl.add declared cls ()
    end)

(* Declares that the function [m] is a method, i.e. a generic that dispatches on
   the class of its first argument. Only a method can have class-overloads, but
   it does not need any: its class-overloads may not be known (e.g. those of
   other packages). As it determines the restrictions of the signatures of [m],
   it must be declared before [m] is given a type.
   [ret] is the return type of the class-overloads of [m], if declared: their
   signatures must comply with it (cf. [check_return_ty]), but not the base
   signatures of [m]. It is lazy, as it may mention classes whose
   class-overloads have not been declared yet: it is only forced once [m] is
   given a type (the classes must then have been declared, cf.
   [declare_classes]).
   Declaring the same method again does nothing, but adding its return type if
   it has none. If it has one, they must be equivalent. *)
let new_method ?ret m t =
  let m = normalize m t in
  let str = string_of_name m in
  let set ret =
    if NameSet.mem m t.bound then
      failwith (Printf.sprintf
        "Cannot declare the method %s%s: %s has already been given a type." str
        (if is_method m t then " with a return type" else "") str)
    else { t with meths=NameMap.add m ret t.meths }
  in
  match NameMap.find_opt m t.meths, ret with
  | None, _ | Some None, Some _ -> set ret
  | Some _, None -> t
  | Some (Some ret), Some ret' ->
    let merged = lazy begin
      let ret, ret' = Lazy.force ret, Lazy.force ret' in
      if GTy.equiv ret ret' then ret
      else failwith (Format.asprintf
        "The method %s is declared with distinct return types: %a and %a." str GTy.pp ret GTy.pp ret')
    end in
    if NameSet.mem m t.bound then begin
      (* No later signature may force it: the types are compared right away. *)
      declare_classes t ; Lazy.force merged |> ignore ; t
    end else { t with meths=NameMap.add m (Some merged) t.meths }

(* Declares the class-overload of the method [m] for the class [cls]: [cls]
   will implement the method class of [m] (named after [r_name m]). The methods
   of a class and the restrictions of the signatures are derived from the
   class-overloads, so they must all be declared before the class is declared
   (i.e. before any type mentions it, cf. [declare_classes]) and before [m] is
   given a type. [m] must have been declared as a method (cf. [new_method]).
   Declaring the same class-overload again does nothing. *)
let new_class_overload m cls t =
  let m = normalize m t in
  if List.mem (m,cls) t.ovl then t
  else begin
    let str = string_of_name m in
    let error reason =
      failwith (Printf.sprintf "Cannot declare the class-overload %s @ %s: %s." str cls reason) in
    if is_method m t |> not then
      error (str^" is not a method (it must be declared first, with 'method "^str^"')") ;
    if NameSet.mem m t.bound then error (str^" has already been given a type") ;
    if Hashtbl.mem declared cls then
      error (cls^" has already been declared (class-overloads must precede any type mentioning their class)") ;
    { t with ovl=t.ovl@[m,cls] }
  end

(* Classes of the class-overloads of the generic [m], in their order of
   declaration, and those declared after the class-overload for [cls]. *)
let overloads m t =
  t.ovl |> List.filter_map (fun (m',c) -> if Name.compare m m' = 0 then Some c else None)
let overloads_after cls m t =
  let rec after clss =
    match clss with
    | [] -> []
    | c::clss when String.equal c cls -> clss
    | _::clss -> after clss
  in
  after (overloads m t)

(* The method class of the generic [m], i.e. the class of the values whose
   class has a class-overload of [m].
   TODO: Method classes are not namespaced: two methods [pa::m] and [pb::m] share
   the method class [@m]. This is unsound: a class with a class-overload of
   [pb::m] only is excluded from the base signatures of [pa::m], and only its
   fallback signature applies (cf. [fallback_ty]). But the return type of
   the latter is the one of the class-overloads of [pa::m], whereas R calls its
   default method. *)
let method_class (_, m) = Rstt.Classes.Method (r_name m)

(* The restriction of the first parameter of a signature of the generic [m]
   (cf. [add_signature]): the values whose class has no class-overload of [m]
   (i.e. [<~@m, ...>]) for a base signature or the one of its default method, and
   those whose class has no class-overload of [m] declared after the one for
   [cls] for the signature of that class-overload (whose first parameter is
   already restricted to [cls], cf. [class_overload_sig]). *)
let restriction origin m t =
  match origin with
  | Base | Default -> if is_method m t then [false, method_class m] else []
  | Overload cls -> overloads_after cls m t |> List.map (fun c -> false, Rstt.Classes.Class c)

(* The return type of the signature [ty]: the union of the codomains of its
   arrows. *)
let codomain ty =
  let open Rstt in
  GTy.ub ty |> Attr.destruct
  |> List.concat_map (fun (ps,_) -> ps)
  |> List.concat_map (fun a -> Arrow.dnf a.Attr.content |> List.concat |> List.map snd)
  |> Ty.disj

(* The fallback signature of the generic [m],
   [(X: <@m, ...>, ...: any) -> ret] (whatever the name of the first parameter
   of [m] is): it covers the values for which the base signatures do not apply,
   i.e. the complement [<@m, ...>] of their restriction [<~@m, ...>] (a class
   implies the method classes it implements). Contrarily to the signatures of
   the methods, it also covers the values of these classes whose other classes
   are unknown.
   [ret] is the return type declared for [m], if any (cf. [new_method]).
   Otherwise, as these values are dispatched to one of the class-overloads of
   [m] (but see the TODO of [method_class]), it is the union of the return types
   of the signatures of its methods [sigs], the type variables of each being
   instantiated with [TVOp.top_instance] before the union (where a variable could
   occur with both polarities, and thus survive). In particular, it is [empty]
   when [m] has no class-overload. It is [any] when this is not possible: when a
   class-overload has no signature (its return type is unknown), one of them
   still contains label variables, or type variables remain after the
   instantiation. This union assumes a fixed context: all the class-overloads of
   [m] (e.g. those of the libraries the project uses) must have been declared. *)
let fallback_ty m sigs t =
  let open Rstt in
  let overloads_ret () =
    let methods = overloads_with_class sigs in
    let has_sig c = List.exists (fun (c',_) -> String.equal c c') methods in
    let symbolic = sigs.symbolic |> List.exists (function
      | Overload _, _ -> true
      | (Base | Default), _ -> false) in
    if symbolic || List.for_all has_sig (overloads m t) |> not then Ty.any else
    let ret = methods
              |> List.map (fun (_,ty) -> codomain ty |> TVOp.top_instance MVarSet.empty)
              |> Ty.disj in
    if GTy.mk ret |> GTy.fv |> MVarSet.is_empty then ret else Ty.any
  in
  let ret = match return_ty m t with
    | Some ret -> ret
    | None -> overloads_ret () |> GTy.mk in
  let field ty = Ty.F.mk_descr (Ty.O.required ty) in
  let x = class_ty [true, method_class m] in
  let dom = Arg.mk { pos_named=["X", field x] ;
                     pos_tl=field Ty.any ; named=[] ; named_tl=field Ty.any } in
  ret |> GTy.map (fun ret -> Arrow.mk dom ret |> Attr.mk_content)

(* Checks that the signature [s] of the class-overload of the method [m] for the
   class [cls] complies with the return type declared for [m], if any: each of
   its arrows must return a subtype of it (if they are gradual, for one of their
   static instances at least). The label variables of a symbolic signature
   are not resolved yet: an arrow whose return type contains some is considered
   to return [any]. *)
let check_return_ty cls m s t =
  match return_ty m t with
  | None -> ()
  | Some ret ->
    let tys = match s with
      | SigFun f ->
        f.decl |> List.map (fun a ->
          match Rstt.FunSig.to_regular_ty a.Rstt.FunSig.ret with
          | b -> f.build b
          | exception Invalid_argument _ -> GTy.any)
      | SigTy ty when is_fun_sig ty -> [GTy.lb ty |> GTy.mk |> codomain |> GTy.mk]
      | SigTy _ -> []
    in
    let complies ty = Ty.leq (GTy.lb ty) (GTy.ub ret) in
    match List.find_opt (fun ty -> complies ty |> not) tys with
    | None -> ()
    | Some ty ->
      failwith (Format.asprintf
        "The signature of %s.%s does not comply with the return type of the method %s: %a is not a subtype of %a."
        (string_of_name m) cls (string_of_name m) GTy.pp ty GTy.pp ret)

(* The values whose class has no class-overload of [m] ([<~@m, ...>]), or that
   have no class. *)
let no_overload m = Ty.cup (class_ty [false, method_class m]) unattributed

(* A partition of the R values the first argument of an application of the
   generic [m] may take, following its dispatch: the values whose class has
   no class-overload of [m] ([<~@m, ...>], which the base signatures cover),
   those of the class [c_i] of each of its class-overloads that have none of
   the classes of the class-overloads declared after it
   ([<c_i, ~c_(i+1), ..., ~c_n, ...>]), and the rest ([<@m, ~c_1, ..., ~c_n,
   ...>], if not empty). It is empty if [m] is not a method. *)
let dispatch_partition m t =
  let m = normalize m t in
  if is_method m t |> not then []
  else
    let clss = overloads m t in
    let base = no_overload m in
    let rec meths clss =
      match clss with
      | [] -> []
      | c::clss ->
        class_ty ((true, Rstt.Classes.Class c)::List.map (fun c -> false, Rstt.Classes.Class c) clss)
        ::meths clss
    in
    let rest = class_ty ((true, method_class m)::List.map (fun c -> false, Rstt.Classes.Class c) clss) in
    base::meths clss@(if Ty.is_empty rest then [] else [rest])

(* The operators of R's [Ops] group generic: contrarily to the other generics,
   they never dispatch to a default method. *)
let ops = ["+";"-";"*";"/";"^";"%%";"%/%";"==";"!=";"<";">";"<=";">=";"&";"|";"!"]

(* The method whose default method is named [str], if any: the one [m] refers to
   (cf. [find_method]) if [str] is [m.default] (unless [m] is an operator, cf.
   [ops]). *)
let generic_of_default (ns, str) t =
  let suffix = ".default" in
  if String.ends_with ~suffix str then
    let m = String.sub str 0 (String.length str - String.length suffix) in
    if List.mem m ops then None else find_method (ns, m) t
  else None

(* Restrictions of the signature of the class-overload of a generic for the
   class [cls]: its first parameter is restricted to the values of class
   [cls]. *)
let class_overload_sig cls f = restrict_sig [true, Rstt.Classes.Class cls] f
let class_overload_ty cls ty = restrict_first_param [true, Rstt.Classes.Class cls] ty

(* ===== Registration of the signatures ===== *)

(* The type of a variable declared with the signatures [sigs] is the
   intersection of its resolved signatures ([any] if there is none), and
   simplified. It is computed lazily (cf. [types]): the applications of the
   variable use its signatures rather than this type (cf. [Transform]). *)
let sigs_ty sigs =
  lazy begin
    let ty =
      match base sigs@defaults sigs@List.map snd (overloads_with_class sigs) with
      | [] -> GTy.any
      | tys -> GTy.conj tys
    in
    TyScheme.mk_poly ty |> simplify_tl
  end

(* The kind of the type of a variable whose signatures have the kind [k], once
   the signature [ty] is added to them: as the type is their intersection, it
   is a function (resp. a non-function) as soon as one of them is. It is only
   an approximation (an intersection of signatures that are neither may still
   be one or the other), but it is computed without building the
   intersection (cf. [sigs_ty]). An empty intersection is a function. *)
let sigs_kind k ty =
  match k, kind_of_ty ty with
  | KFun, _ | _, KFun -> KFun
  | KVal, _ | _, KVal -> KVal
  | KAny, KAny -> KAny

(* The first parameter of a signature of [name] is restricted as described by
   [restriction]. That of a class-overload must comply with the return type of
   its method. If the type of [v] was inferred, it is kept as a base signature. *)
let add_signature ?(origin=Base) ~name v s t =
  let name = normalize name t in
  begin match origin with
  | Overload cls -> check_return_ty cls name s t
  | Base | Default -> ()
  end ;
  let restr = restriction origin name t in
  let s =
    match s with
    | SigTy ty -> SigTy (restrict_first_param restr ty)
    | SigFun f -> SigFun (restrict_sig restr f)
  in
  let t = { t with bound=NameSet.add name t.bound } in
  let sigs = get_sigs v t in
  let add ty sigs =
    { sigs with regular=(origin,ty)::sigs.regular ; kind=sigs_kind sigs.kind ty } in
  let sigs =
    match s with
    | SigTy ty -> add ty sigs
    | SigFun f when is_resolved f -> add (fsig_ty f) sigs
    | SigFun f -> { sigs with symbolic=(origin,f)::sigs.symbolic }
  in
  let sigs =
    if is_method name t
    then { sigs with generic=Some name ; fallback=[fallback_ty name sigs t] }
    else sigs
  in
  { t with types=VarMap.add v (sigs_ty sigs) t.types ;
           kinds=VarMap.add v (Lazy.from_val sigs.kind) t.kinds ;
           senv=VarMap.add v sigs t.senv }

(* An inferred type is restricted as a signature would be. *)
let set_from_tyscheme v ts t =
  if TyScheme.fv ts |> MVarSet.is_empty |> not then
    failwith "Top-level definitions cannot contain monomorphic type variables." ;
  let ts, t =
    match Variable.get_name v with
    | None -> ts, t
    | Some name ->
      let name = None, name in
      let t = { t with bound=NameSet.add name t.bound } in
      match restriction Base name t with
      | [] -> ts, t
      | restr ->
        let tvs, ty = TyScheme.get ts in
        TyScheme.mk tvs (restrict_first_param restr ty), t
  in
  let ts = simplify_tl ts in
  { t with types=VarMap.add v (Lazy.from_val ts) t.types ;
           kinds=VarMap.add v (lazy (kind_of_tyscheme ts)) t.kinds ;
           senv=VarMap.remove v t.senv }

let mem v t = VarMap.mem v t.types
let kind v t =
  match VarMap.find_opt v t.kinds with
  | Some k -> Lazy.force k
  | None -> KAny
let env dom t =
  VarSet.fold (fun v env ->
    match VarMap.find_opt v t.types with
    | Some ts -> Env.add v (Lazy.force ts) env
    | None -> env
  ) dom Env.empty
let get v t = VarMap.find v t.types |> Lazy.force
let get_signatures v t = VarMap.find_opt v t.senv

let fallback sigs = sigs.fallback
let symbolic sigs = sigs.symbolic
let generic sigs = sigs.generic
let all sigs =
  base sigs@defaults sigs@List.map snd (overloads_with_class sigs)@sigs.fallback
(* The values the first argument must be a subtype of for the signatures of
   origin [origin] to be considered in inference mode. *)
let inference_guard sigs origin =
  match origin, sigs.generic with
  | Base, _ -> None
  | Default, Some m -> Some (no_overload m)
  | Default, None -> None
  | Overload cls, _ -> Some (class_ty [true, Rstt.Classes.Class cls])

(* ===== Namespaces ===== *)

let ns_find ns name t =
  StrMap.find_opt ns t.ns |> Option.map (StrMap.find_opt name) |> Option.join

(* The variable of [ns::name], created if there is none.
   The successive signatures of a same name are its overloads: contrarily to a
   top-level name, a namespaced one is never redefined by the program, so a new
   signature cannot be shadowing the previous ones. *)
let ns_var ns name t =
  match ns_find ns name t with
  | Some v -> v, t
  | None ->
    let v = Mlsem.Lang.MVariable.create Immut (Some (string_of_name (Some ns, name))) in
    let names = StrMap.find_opt ns t.ns |> Option.value ~default:StrMap.empty in
    v, { t with ns=StrMap.add ns (StrMap.add name v names) t.ns }
let ns_add_signature ns name s t =
  let v, t = ns_var ns name t in
  add_signature ~name:(Some ns, name) v s t

(* The imports of the package being typed, as R's imports environment: a
   namespace no R code can name, searched first (cf. [search]). *)
let imports_ns = "<imports>"

let ns_import ?names ?(except=[]) ns t =
  let names = match names with
    | Some names -> names
    | None ->
      StrMap.find_opt ns t.ns |> Option.value ~default:StrMap.empty
      |> StrMap.bindings |> List.map fst
  in
  let names = List.filter (fun name -> not (List.mem name except)) names in
  let add imports name =
    let v = match ns_find ns name t with
      | Some v -> v
      | None -> Mlsem.Lang.MVariable.create Immut (Some (ns^"::"^name))
    in
    StrMap.add name v imports
  in
  let imports = StrMap.find_opt imports_ns t.ns |> Option.value ~default:StrMap.empty in
  let imports = List.fold_left add imports names in
  let from = List.fold_left (fun from name -> StrMap.add name ns from) t.imports names in
  { t with ns=StrMap.add imports_ns imports t.ns ; imports=from }

let set_self name t = { t with self=Some name }
let self t = t.self

let search name t =
  List.find_map (fun ns -> ns_find ns name t) (imports_ns::search_path)
