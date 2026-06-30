open R_types
open Types
open Mlsem.Common
module MVariable = Mlsem.Lang.MVariable
module SA = Mlsem.System.Ast

let resolve ty = Builder.resolve Builder.empty_env ty |> snd
let build = Builder.build Builder.TIdMap.empty
let build_noattr = Builder.build_struct Builder.TIdMap.empty
let ty str = IO.parse_type_string(str) |> resolve |> build
let gen ty = Mlsem_types.GTy.mk ty |> Mlsem_types.TyScheme.mk_poly

module BuiltinOp = struct
  let eq = MVariable.create Immut (Some "==")
  let neq = MVariable.create Immut (Some "!=")
  let ty_comp = ty "(a:any, b:any) -> ^lgl1" |> gen
  let all = [ eq, ty_comp ; neq, ty_comp ]
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
let tobool =
  let open Mlsem.Types in
  let def = Arrow.mk Ty.any Ty.bool in
  let tt = Arrow.mk truthy Ty.tt in
  let ff = Arrow.mk falsy Ty.ff in
  let ty = Ty.conj [def;tt;ff] in
  gen ty
let tobool_op = SA.OCustom { oname="tobool" ; ofun=tobool ; ogen=false }
let extract = ty "({'a} --> 'a) & (v('p) --> v1('p))" |> gen
let extract_op = SA.OCustom { oname="extract" ; ofun=extract ; ogen=false }
let flattell = ty "@(...:'v) --> @(...:'v)" |> gen
let flattell_op = SA.OCustom { oname="flattell" ; ofun=flattell ; ogen=false }

let initial_env =
  let add_def env (v,ty) = Env.add v ty env in
  List.fold_left add_def Env.empty BuiltinOp.all
