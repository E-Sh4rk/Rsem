let proj_content ty =
  let open Mlsem.Types in
  let tvs, ty = TyScheme.get ty in
  let ty = GTy.map (fun ty -> Rstt.Attr.proj_content ty) ty in
  TyScheme.mk tvs ty

let rec cartesian_prod lst =
  match lst with
  | [] -> [[]]
  | es::lst ->
    let tls = cartesian_prod lst in
    es |> List.concat_map
      (fun e -> tls |> List.map (fun tl -> e::tl))

let decompose_fun ty =
  let open Mlsem.Types in
  let (poly,ty) = TyScheme.get ty in
  let lb, ub = GTy.lb ty, GTy.ub ty in
  let aux ps =
    ps |> List.map (fun (a,b) -> Arrow.mk a b)
  in
  let lbs = Arrow.dnf lb |> cartesian_prod |> List.concat_map aux in
  lbs |> List.map (fun lb -> GTy.mk_gradual lb (Ty.cup lb ub) |> TyScheme.mk poly) 
