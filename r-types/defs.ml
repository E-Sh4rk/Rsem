open Types

module Args = struct
  let id_of_name str =
    str
  let id_of_pos i =
    Format.asprintf "__%i__" i
  let id_of_null = "__NULL__"
  let id_of_ellipsis = "..."
end

module Vecs = struct
  let na = Enum.define "NA" |> Enum.typ
  let int = Enum.define "INT" |> Enum.typ
  let lgl = Enum.define "LGL" |> Enum.typ
  let dbl = Enum.define "DBL" |> Enum.typ
  let clx = Enum.define "CLX" |> Enum.typ
  let chr = Enum.define "CHR" |> Enum.typ
  let raw = Enum.define "RAW" |> Enum.typ
  let int_na =
    let ty = Ty.cup int na in
    Ty.register "INT?" ty ; ty
  let lgl_na =
    let ty = Ty.cup lgl na in
    Ty.register "LGL?" ty ; ty
  let dbl_na =
    let ty = Ty.cup dbl na in
    Ty.register "DBL?" ty ; ty
  let clx_na =
    let ty = Ty.cup clx na in
    Ty.register "CLX?" ty ; ty
  let chr_na =
    let ty = Ty.cup chr na in
    Ty.register "CHR?" ty ; ty
  let raw_na =
    let ty = Ty.cup raw na in
    Ty.register "RAW?" ty ; ty
  let vec =
    let ty = Ty.disj [ int;lgl;dbl;clx;chr;raw ] in
    Ty.register "VEC" ty ; ty
  let vec_na =
    let ty = Ty.cup vec na in
    Ty.register "VEC?" ty ; ty
end

module Null = struct
  let null = Enum.define "Null" |> Enum.typ
end
