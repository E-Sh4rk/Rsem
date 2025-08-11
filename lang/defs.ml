open R_types
open Types
open Common

let unref, unref_t = failwith "TODO"
let cref, cref_t = failwith "TODO"

let defs = [unref, unref_t ; cref, cref_t]

let initial_env =
  let add_def env (v,ty) =
    Env.add v (GTy.mk ty |> TyScheme.mk_poly) env
  in
  List.fold_left add_def Env.empty defs
  