open Mlsem_types
open Mlsem_common

type t

val initial : t
val add_signature : Variable.t -> TyScheme.t -> t -> t
val replace_signature : Variable.t -> TyScheme.t -> t -> t
val env : t -> Env.t
val get_sym_signature : Variable.t -> t -> TyScheme.t
