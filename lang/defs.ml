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

let defs = [unref, unref_t ; cref, cref_t]

let initial_env =
  let add_def env (v,ty) =
    Env.add v (GTy.mk ty |> TyScheme.mk_poly) env
  in
  List.fold_left add_def Env.empty defs
  