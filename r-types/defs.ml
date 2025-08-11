open Types

module Args = struct
  let id_of_name str =
    str
  let id_of_pos i =
    Format.asprintf "__%i__" i
  let id_of_null = "__NULL__"
  let id_of_ellipsis = "..."
end

open Sstt.Extensions.Hierarchy
let _h =
  let h = new_hierarchy () in
  printer_params' h |> Types.Ty.add_printer_param ;
  h

module Scalars = struct
  let _scalar name =
    let n = new_node _h ~name ~subnodes:[] in
    n, mk _h n
  let intn, int = _scalar "int"
  let lgln, lgl = _scalar "lgl"
  let dbln, dbl = _scalar "dbl"
  let clxn, clx = _scalar "clx"
  let chrn, chr = _scalar "chr"
  let rawn, raw = _scalar "raw"

  let scalar =
    let ty = Ty.disj [ int;lgl;dbl;clx;chr;raw ] in
    Ty.register "scalar" ty ; ty
end

module Vecs = struct  
  let _vec scalar name =
    let n = new_node _h ~name ~subnodes:[scalar] in
    n, mk _h n
  let intn, int = _vec Scalars.intn "INT"
  let lgln, lgl = _vec Scalars.lgln "LGL"
  let dbln, dbl = _vec Scalars.dbln "DBL"
  let clxn, clx = _vec Scalars.clxn "CLX"
  let chrn, chr = _vec Scalars.chrn "CHR"
  let rawn, raw = _vec Scalars.rawn "RAW"

  let _vec_na vec name =
    let n = new_node _h ~name ~subnodes:[vec] in
    n, mk _h n
  let int_na_n, int_na = _vec_na intn "INT?"
  let lgl_na_n, lgl_na = _vec_na lgln "LGL?"
  let dbl_na_n, dbl_na = _vec_na dbln "DBL?"
  let clx_na_n, clx_na = _vec_na clxn "CLX?"
  let chr_na_n, chr_na = _vec_na chrn "CHR?"
  let raw_na_n, raw_na = _vec_na rawn "RAW?"

  let vec =
    let ty = Ty.disj [ int;lgl;dbl;clx;chr;raw ] in
    Ty.register "VEC" ty ; ty
  let vec_na =
    let ty = Ty.disj [ int_na;lgl_na;dbl_na;clx_na;chr_na;raw_na ] in
    Ty.register "VEC?" ty ; ty
end

module Null = struct
  let null = Enum.define "Null" |> Enum.typ
end

module Ref = struct
  let abs = Abstract.define "ref" [Inv]
  let mk ty = Abstract.mk abs [ty]
end