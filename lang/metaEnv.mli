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
val is_resolved : fsig -> bool
(* Whether the signature contains no label variable, i.e. whether it can be
   converted to a set-theoretic type as is. *)
val fsig_ty : ?polymorphic:bool -> fsig -> GTy.t
(* The type of the signature. If [polymorphic] is true (it defaults to false),
   its argument is built with a polymorphic identifier, so that it can be
   matched with the argument of any definition.
   @raise Invalid_argument if [is_resolved] is false. *)

type sigs = { resolved:GTy.t list ; symbolic:fsig list }
(* Signatures declared for a variable: those that could be converted to a type,
   and the function signatures that still contain label variables. *)
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
val add_signature : Variable.t -> signature -> t -> t
val new_class_overload : Variable.t -> string -> t -> t
val class_overload_sig : string -> fsig -> fsig
val class_overload_ty : string -> GTy.t -> GTy.t
val set_from_tyscheme : Variable.t -> TyScheme.t -> t -> t
val mem : Variable.t -> t -> bool
val env : t -> Env.t
val get : Variable.t -> t -> TyScheme.t
val get_signatures : Variable.t -> t -> sigs option
val resolve_signature : Ty.t -> fsig -> GTy.t option
(* [resolve_signature arg s] resolves the label variables of [s] using the type
   [arg] of the argument the function is applied to. *)
