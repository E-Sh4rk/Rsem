open Mlsem_types
open Mlsem_common

type label = string
type arg_label = Positional | Named of label | Ell
type 'a arg = arg_label * 'a
val pp_label : Format.formatter -> label -> unit
val pp_arg : (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a arg -> unit
val pp_arg_label : Format.formatter -> arg_label -> unit

type t

val initial : t
val add_signature : Variable.t -> TyScheme.t -> t -> t
val replace_signature : Variable.t -> TyScheme.t -> t -> t
val env : t -> Env.t
val get_signature : Variable.t -> t -> TyScheme.t
val get_fun_signature : Variable.t -> Rstt.Labels.t option arg list -> t -> TyScheme.t
