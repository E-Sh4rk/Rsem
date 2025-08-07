open Defs

module Ext = struct
  type vec = INT |  LGL | DBL | CLX | CHR | RAW
  type t =
    | Na
    | Vec of bool * vec

  let to_typ _ t =
    match t with
    | Na -> Vecs.na
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
end

include (Types.Builder'.Make(Ext))

type type_def = string * type_expr
type type_defs = type_def list
