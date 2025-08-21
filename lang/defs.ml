open R_types
open Types
open Common

let tv = TVar.mk TVar.KTemporary (Some "'a")

let unref, unref_t =
  let v = Variable.create_let (Some "unref") in
  let ty = Arrow.mk (Ref.mk (TVar.typ tv)) (TVar.typ tv) in
  v, ty

let cref, cref_t =
  let v = Variable.create_let (Some "cref") in
  let ty = Arrow.mk (TVar.typ tv) (Ref.mk (TVar.typ tv)) in
  v, ty

let setref, setref_t =
  let v = Variable.create_let (Some "setref") in
  let ty = Arrow.mk (Tuple.mk [Ref.mk (TVar.typ tv) ; TVar.typ tv]) (TVar.typ tv) in
  v, ty

let uref, uref_t =
  let v = Variable.create_let (Some "uref") in
  let ty = Ref.mk (TVar.typ tv) in
  v, ty

let tobool, tobool_t =
  let v = Variable.create_let (Some "tobool") in
  let def = Arrow.mk Ty.any Ty.bool in
  let tt = Arrow.mk (Ty.disj [Prim.tt;Vecs.mk_singl Prim.tt]) Ty.tt in
  let ff = Arrow.mk (Ty.disj [Prim.ff;Vecs.mk_singl Prim.ff]) Ty.ff in
  let ty = Ty.conj [def;tt;ff] in
  v, ty

let defs = [unref, unref_t ; cref, cref_t ; setref, setref_t ; uref, uref_t ; tobool, tobool_t]

let initial_env =
  let add_def env (v,ty) =
    Env.add v (GTy.mk ty |> TyScheme.mk_poly) env
  in
  List.fold_left add_def Env.empty defs
  