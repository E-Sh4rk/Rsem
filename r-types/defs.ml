open Types

module Args = struct
  let id_of_name str =
    str
  let id_of_pos i =
    Format.asprintf "__%i__" i
  let id_of_null = "__NULL__"
  let id_of_ellipsis = "..."
end

module Scalars = struct
  let int = Enum.define "int" |> Enum.typ
  let lgl = Enum.define "lgl" |> Enum.typ
  let dbl = Enum.define "dbl" |> Enum.typ
  let clx = Enum.define "clx" |> Enum.typ
  let chr = Enum.define "chr" |> Enum.typ
  let raw = Enum.define "raw" |> Enum.typ
end

module Vecs = struct
  let _na str = Enum.define ("_NA_"^str) |> Enum.typ

  let _vec scalar str =
    let ty = Enum.define ("_VEC_"^str) |> Enum.typ in
    let ty = Ty.cup ty scalar in
    Ty.register str ty ; ty
  let int = _vec Scalars.int "INT"
  let lgl = _vec Scalars.lgl "LGL"
  let dbl = _vec Scalars.dbl "DBL"
  let clx = _vec Scalars.clx "CLX"
  let chr = _vec Scalars.chr "CHR"
  let raw = _vec Scalars.raw "RAW"

  let _vec_na vec str =
    let ty = Ty.cup vec (_na str) in
    Ty.register (str^"?") ty ; ty
  let int_na = _vec_na int "INT"
  let lgl_na = _vec_na lgl "LGL"
  let dbl_na = _vec_na dbl "DBL"
  let clx_na = _vec_na clx "CLX"
  let chr_na = _vec_na chr "CHR"
  let raw_na = _vec_na raw "RAW"

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
