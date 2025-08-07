open Ast
open Common
open R_types
open Types
module A = System.Ast
module C = System.Const

let typeof_const c =
  match c with
  | CChr _ -> Vecs.chr
  | CDbl _ -> Vecs.dbl
  | CLgl _ -> Vecs.lgl
  | CNull -> Null.null

let rec aux_e (eid,e) =
  let rec aux e =
    match e with
    | Const c -> A.Value (typeof_const c |> GTy.mk)
    | Id v -> A.Var v
    | Unop (v,e) -> aux (Call ((Eid.dummy, Id v), [(Args.id_of_pos 0, e)]))
    | Call (f, args) ->
      let args = List.map (fun (lbl,e) -> lbl,e,Variable.create_gen None) args in
      let a = Eid.dummy, A.Value (Record.empty_closed |> GTy.mk) in
      let add_arg a (lbl, _, x) =
        let xe = Eid.dummy, A.Var x in
        Eid.dummy, A.Constructor (A.RecUpd lbl, [a; xe])
      in
      let add_ellipsis a args =
        let xs = args |> List.map (fun (_,_,x) -> Eid.dummy, A.Var x) in
        let ell = Eid.dummy, A.Constructor (A.Choice (List.length xs), xs) in
        Eid.dummy, A.Constructor (A.RecUpd Args.id_of_ellipsis, [a; ell])
      in
      let add_def e (_, def, x) =
        A.Let ([], x, aux_e def, (Eid.dummy, e))
      in
      let a = List.fold_left add_arg a args in
      let a = add_ellipsis a args in
      let e = A.App (aux_e f, a) in
      List.fold_left add_def e args
  in
  (eid, aux e)

let to_mlsem e = aux_e e
