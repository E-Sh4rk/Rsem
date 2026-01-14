open R_types
open Types
open Mlsem.Common
module MVariable = Mlsem.Lang.MVariable

let resolve ty = Builder.resolve Builder.empty_env ty |> snd
let build = Builder.build Builder.TIdMap.empty
let truthy = IO.parse_type_string("v1(^tt)") |> resolve |> build
let falsy = IO.parse_type_string("v1(^ff)") |> resolve |> build

let test_type = Mlsem.Types.Ty.tt
let tobool, tobool_t =
  let open Mlsem.Types in
  let v = MVariable.create Immut (Some "tobool") in
  let def = Arrow.mk Ty.any Ty.bool in
  let tt = Arrow.mk truthy Ty.tt in
  let ff = Arrow.mk falsy Ty.ff in
  let ty = Ty.conj [def;tt;ff] in
  v, ty

let defs = [tobool, tobool_t]

let initial_env =
  let open Mlsem.Types in
  let add_def env (v,ty) =
    Env.add v (GTy.mk ty |> TyScheme.mk_poly) env
  in
  List.fold_left add_def Env.empty defs
