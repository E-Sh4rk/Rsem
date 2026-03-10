open Sstt

let proj_content ty =
  let open Mlsem.Types in
  let tvs, ty = TyScheme.get ty in
  let ty = GTy.map (fun ty -> Rstt.Attr.proj_content ty) ty in
  TyScheme.mk tvs ty

let decompose_fun_arg ty =
  let open Mlsem.Types in
  let (mono,ty) = TyScheme.get_fresh ty in
  let ty = GTy.ub ty in
  let aux (ps, _) =
    let aux (s,_) =
      let s = TVOp.top_instance mono s in
      if TVOp.vars s |> MixVarSet.subset mono then Some s
      else None
    in
    List.filter_map aux ps
  in
  Sstt.Ty.def ty |> VDescr.get_descr |> Descr.get_arrows |> Arrows.dnf
  |> List.concat_map aux
