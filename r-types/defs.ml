open Types.Builder

type type_def = string * type_expr

type type_defs = type_def list

module Args = struct
  let id_of_name str =
    str
  let id_of_pos i =
    Format.asprintf "__%i__" i
  let id_of_null = "__NULL__"
  let id_of_ellipsis = "..."
end