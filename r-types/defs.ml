open Types

module CArgs = struct
  open Args
  let cons (npos,names,nrem) lst =
    let definite, rem = split_at_index lst (npos + (List.length names)) in
    assert (List.length rem = nrem) ;
    let pos, named = split_at_index definite npos in
    let named = List.map2 (fun ty lbl -> lbl,ty) named names in
    mk_concrete (pos,named,rem)
  let cdom (npos,names,nrem) ty =
    try
      destruct ty
      |> List.filter_map (fun (pos,named,ell,o) ->
        let ty' = mk (pos,named,ell,o) in
        if Ty.leq ty' ty then
          Some (List.concat [List.map snd pos ;
                List.map (fun (_,_,ty) -> ty) named ;
                List.init nrem (fun _ -> ell)])
        else None
      )
    with Invalid_argument _ ->
      let n = npos + (List.length names) + nrem in
      [List.init n (fun _ -> Ty.any)]
end

module PArgs = struct
  open Args
  let mk_from_def = mk_from_def
  let proj name ty = proj_arg name ty
  let proj_ell ty = proj_ellipsis ty
  let pdom _ = Ty.any (* Should be ok by construction *)
end

(* open Sstt.Extensions.Hierarchy *)
(* let _h =
  let h = new_hierarchy () in
  printer_params h |> Types.Ty.add_printer_param ;
  h *)

(* module Scalars = struct
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
end *)

(* module Vecs = struct  
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
end *)

include Vectors

module Null = struct
  let null = Enum.define "Null" |> Enum.typ
end

module Ref = struct
  let abs = Abstract.define "ref" 1
  let mk ty = Abstract.mk abs [ty]
end