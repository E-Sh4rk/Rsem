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

type sigs
(* Signatures declared for a variable. Those of a generic [m] with
   class-overloads (a "method") are of three kinds:
   - its base signatures, i.e. the ones declared for [m] itself. Their first
     parameter is restricted to the values whose class has no class-overload
     of [m], i.e. to [<~@m, ...>] (with [@m] the method class of [m]);
   - the signatures of its methods, i.e. of its class-overloads, each with the
     class [c_i] it is the class-overload for. Their first parameter is
     restricted to [<c_i, ~c_(i+1), ..., ~c_n, ...>], where
     [c_(i+1), ..., c_n] are the classes of the class-overloads of [m]
     declared after the one for [c_i] (which take precedence over it);
   - the default signature of its methods,
     [(X: <@m, ...>, ...: any) -> ret], which covers the values the base
     signatures do not apply to, i.e. [<@m, ...>] (a class implies the method
     classes it implements, so these are the values of the classes that have
     a class-overload of [m], whatever their other classes are). The
     signatures of the methods do not cover all of them, as
     [<@m, ~c_1, ..., ~c_n, ...>] is not empty. With it, the signatures of a
     method cover all the values its base signatures cover, and those of
     unknown classes (e.g. [dbl]) in particular. [ret] is the union of the
     return types of the signatures of the methods (their type variables
     instantiated with their largest instance), or [any] if one of its
     class-overloads has no signature or one that still contains label
     variables, or if type variables remain.
   A function that is not a method only has base signatures (whose first
   parameter is not restricted). Each kind only lists the signatures that
   could be converted to a type: the function signatures that still contain
   label variables are listed apart ([symbolic]).
   The type of the variable is the intersection of its base and method
   signatures: the default signature of the methods is only used for its
   applications (cf. [Transform]). *)
val base : sigs -> GTy.t list
val methods : ?cls:string -> sigs -> GTy.t list
(* [methods ~cls sigs] are the signatures of the method for the class [cls],
   and [methods sigs] those of all the methods. *)
val methods_with_class : sigs -> (string * GTy.t) list
(* The signatures of the methods, each with its class. *)
val methods_default : sigs -> GTy.t list
(* The default signature of the methods (none if the function is not a
   method). *)
val all : sigs -> GTy.t list
(* All the signatures of the three kinds above. *)
val symbolic : sigs -> (string option * fsig) list
(* The signatures that still contain label variables, with the class of the
   method they are a signature of, if any. *)
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
   [name]: as a base signature, or as the signature of the method for [cls]
   (whose first parameter must already be restricted to [cls], cf.
   [class_overload_sig]). Its first parameter is restricted as described for
   [sigs]. *)
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
val dispatch_partition : string -> t -> Ty.t list
(* [dispatch_partition m t] partitions the R values of the first argument of an
   application of the generic [m] following its dispatch: [<~@m, ...>], then
   [<c_i, ~c_(i+1), ..., ~c_n, ...>] for each class-overload of [m], and the
   rest. It is empty if [m] is not a method. *)
val class_overload_sig : string -> fsig -> fsig
val class_overload_ty : string -> GTy.t -> GTy.t
(* Restriction of the signature of a class-overload for the class [cls]: its
   first parameter is restricted to the values of class [cls]. *)
val mem : Variable.t -> t -> bool
val env : VarSet.t -> t -> Env.t
(* [env dom t] is the typing environment of the variables of [dom] (those of
   [dom] that [t] does not bind are left out). The types are simplified when
   stored, lazily: only those of the variables of [dom] are computed. *)
val get : Variable.t -> t -> TyScheme.t
(* @raise Not_found if [mem v t] is false. *)
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
