open R_types
open Types
open Mlsem.Common
module MVariable = Mlsem.Lang.MVariable

let resolve ty = Builder.resolve Builder.empty_env ty |> snd
let build = Builder.build Builder.TIdMap.empty
let ty str = IO.parse_type_string(str) |> resolve |> build

module BuiltinOp = struct
  let eq = MVariable.create Immut (Some "==")
  let neq = MVariable.create Immut (Some "!=")
  let unclass = MVariable.create Immut (Some "unclass")
  let ty_comp = ty "(a:any, b:any) -> ^lgl1"
  let ty_unclass = ty "(a:'a<...>) -> 'a<>"
  let all = [ eq, ty_comp ; neq, ty_comp ; unclass, ty_unclass ]
  let find_builtin str =
    let f (v,_) =
      match Variable.get_name v with
      | None -> false
      | Some name -> String.equal name str
    in
    List.find_opt f all |> Option.map fst
end

let truthy, falsy = ty "tt", ty "ff"
let test_type = Mlsem.Types.Ty.tt
let tobool, tobool_t =
  let open Mlsem.Types in
  let v = MVariable.create Immut (Some "tobool") in
  let def = Arrow.mk Ty.any Ty.bool in
  let tt = Arrow.mk truthy Ty.tt in
  let ff = Arrow.mk falsy Ty.ff in
  let ty = Ty.conj [def;tt;ff] in
  v, ty

let defs = [tobool, tobool_t]@BuiltinOp.all

let initial_env =
  let open Mlsem.Types in
  let add_def env (v,ty) =
    Env.add v (GTy.mk ty |> TyScheme.mk_poly) env
  in
  List.fold_left add_def Env.empty defs
