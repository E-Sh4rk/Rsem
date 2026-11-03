open Mlsem_types
open Mlsem_common

type builder = (Rstt.Var.t, Rstt.RowVar.t, Rstt.Builder.TId.t) Rstt.Builder.t
type funsig = (Rstt.Var.t, Rstt.RowVar.t, Rstt.Builder.TId.t) Rstt.FunSig.t

(* Declared signature of a function. It is kept in its [FunSig] form, as a
   signature containing label variables can only be converted to a
   set-theoretic type once these variables have been resolved (which requires
   the type of the argument the function is applied to). *)
type fsig
val mk_fsig : (builder -> GTy.t) -> funsig -> fsig
(* [mk_fsig build decl] is the signature [decl], the types it mentions being
   converted with [build] (which resolves the type aliases they use). *)
val arrows : fsig -> fsig list
(* The arrows of a signature (which is their intersection), each as a
   signature of its own, with the same restrictions. *)
val is_resolved : fsig -> bool
(* Whether the signature contains no label variable, i.e. whether it can be
   converted to a set-theoretic type as is. *)
val fsig_ty : ?polymorphic:bool -> fsig -> GTy.t
(* The type of the signature. If [polymorphic] is true (it defaults to false),
   its argument is built with a polymorphic identifier, so that it can be
   matched with the argument of any definition.
   @raise Invalid_argument if [is_resolved] is false. *)

type sigs = { resolved:GTy.t list ; methods:GTy.t list ; symbolic:fsig list }
(* Signatures declared for a variable: those that could be converted to a type,
   and the function signatures that still contain label variables. [methods]
   are those of [resolved] that come from its class-overloads. *)
type signature = SigTy of GTy.t | SigFun of fsig

type label = string
type arg_label = Positional | Named of label | Ell
type 'a arg = arg_label * 'a
val pp_label : Format.formatter -> label -> unit
val pp_arg : (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a arg -> unit
val pp_arg_label : Format.formatter -> arg_label -> unit

type t

(* val simplify_tl : TyScheme.t -> TyScheme.t *)

val initial : t
val add_signature : ?cls:string -> name:string -> Variable.t -> signature -> t -> t
(* [add_signature ~name v s t] adds the signature [s] to [v], a variable named
   [name]. The first parameter of [s] is restricted to the values whose class
   has no class-overload of [name] taking precedence over [s]: none if [s] is
   the signature of the class-overload of [name] for [cls], none declared
   after it otherwise. *)
val set_from_tyscheme : Variable.t -> TyScheme.t -> t -> t
(* The type of [v] is restricted as a signature of its name would be. *)

val new_class_overload : string -> string -> t -> t
(* [new_class_overload m cls t] declares the class-overload of the generic
   named [m] for the class [cls], after the ones already declared: [cls] will
   implement the method class of [m]. It has no effect if it already does.
   @raise Failure if [cls] has already been declared (cf. [declare_classes]) or
   [m] given a type. *)
val declare_classes : t -> unit
(* Declares the classes of the class-overloads of [t] that have not been
   declared yet, with their methods. It must be called before any type
   mentioning these classes is built, and makes later class-overloads for them
   fail. *)
val class_overload_sig : string -> fsig -> fsig
val class_overload_ty : string -> GTy.t -> GTy.t
(* Restriction of the signature of a class-overload for the class [cls]: its
   first parameter is restricted to the values of class [cls]. *)
val mem : Variable.t -> t -> bool
val env : t -> Env.t
val get : Variable.t -> t -> TyScheme.t
val get_signatures : Variable.t -> t -> sigs option
val resolve_signature : Ty.t -> fsig -> GTy.t option
(* [resolve_signature arg s] resolves the label variables of [s] using the type
   [arg] of the argument the function is applied to. *)

val ns_find : string -> string -> t -> Variable.t option
(* [ns_find ns name t] is the variable R code reaches with [ns::name], if a
   signature has been declared for it. *)
val ns_add_signature : string -> string -> signature -> t -> t
(* [ns_add_signature ns name s t] declares [s] as a signature of [ns::name], in
   addition to the ones it already has. *)
val search : string -> t -> Variable.t option
(* [search name t] is the variable an unqualified [name] reaches when no
   top-level definition binds it: the one of the first namespace of R's default
   search path (which ends with [base]) that declares [name]. *)
