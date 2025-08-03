open Ast
open Common
module A = System.Ast

let aux_const c =
  match c with
  | CStr str -> A.String str

let rec aux_e (eid,e) =
  let e = match e with
  | Const c -> A.Const (aux_const c)
  | Id v -> A.Var v
  | Call (f, args) ->
    let a = Eid.dummy, A.Const A.EmptyRecord in
    let add_arg a (lbl, eo) =
      match eo with
      | None -> a
      | Some e -> Eid.dummy, A.Constructor (A.RecUpd lbl, [a;aux_e e])
    in
    let a = List.fold_left add_arg a args in
    A.App (aux_e f, a)
  in
  (eid, e)

let to_mlsem e = aux_e e
