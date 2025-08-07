open Defs

module Ext = struct
  type prim = INT |  LGL | DBL | CLX | CHR | RAW
  type t =
    | Vec of bool * prim
    | Scalar of prim

  let to_typ _ t =
    match t with
    | Vec (false, INT) -> Vecs.int
    | Vec (false, LGL) -> Vecs.lgl
    | Vec (false, DBL) -> Vecs.dbl
    | Vec (false, CLX) -> Vecs.clx
    | Vec (false, CHR) -> Vecs.chr
    | Vec (false, RAW) -> Vecs.raw
    | Vec (true, INT) -> Vecs.int_na
    | Vec (true, LGL) -> Vecs.lgl_na
    | Vec (true, DBL) -> Vecs.dbl_na
    | Vec (true, CLX) -> Vecs.clx_na
    | Vec (true, CHR) -> Vecs.chr_na
    | Vec (true, RAW) -> Vecs.raw_na
    | Scalar INT -> Scalars.int
    | Scalar LGL -> Scalars.lgl
    | Scalar DBL -> Scalars.dbl
    | Scalar CLX -> Scalars.clx
    | Scalar CHR -> Scalars.chr
    | Scalar RAW -> Scalars.raw
end

include (Types.Builder'.Make(Ext))

type type_def =
| Sig of string * type_expr
| Aliases of (string * string list * type_expr) list
type type_defs = type_def list
