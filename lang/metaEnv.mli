open Mlsem_types
open Mlsem_common

type sigs = { resolved:GTy.t list ; symbolic:GTy.t list }

type label = string
type arg_label = Positional | Named of label | Ell
type 'a arg = arg_label * 'a
val pp_label : Format.formatter -> label -> unit
val pp_arg : (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a arg -> unit
val pp_arg_label : Format.formatter -> arg_label -> unit

type t

(* val simplify_tl : TyScheme.t -> TyScheme.t *)

val initial : t
val add_signature : Variable.t -> GTy.t -> t -> t
val set_from_tyscheme : Variable.t -> TyScheme.t -> t -> t
val mem : Variable.t -> t -> bool
val env : t -> Env.t
val get : Variable.t -> t -> TyScheme.t
val get_signatures : Variable.t -> t -> sigs option
val resolve_signature : Rstt.Labels.t option arg list -> GTy.t -> GTy.t option
