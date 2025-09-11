open Ast
open Common
open R_types
open Types
module A = System.Ast
module C = System.Const

(* Tranformations *)

let eliminate_return e =
  let rec aux (id,e) n ret cont =
    match e with
    | Const _ | Id _ -> fill_hole cont n (id,e)
    | Declare (v, None, e2) ->
      let ctx2 = id, Declare (v, None, hole n) in
      aux e2 n (fill_hole ret n ctx2) (fill_hole cont n ctx2)
    | Declare (v, Some e1, e2) ->
      let m = fresh_hole_id () in
      let ctx2 = id, Declare (v, Some (hole m), hole n) in
      let cont = aux e2 n (fill_hole ret n ctx2) (fill_hole cont n ctx2) in
      let ret = fill_hole ret n (hole m) in
      aux e1 m ret cont
    | Let (v, e1, e2) ->
      let m = fresh_hole_id () in
      let ctx2 = id, Let (v, hole m, hole n) in
      let cont = aux e2 n (fill_hole ret n ctx2) (fill_hole cont n ctx2) in
      let ret = fill_hole ret n (hole m) in
      aux e1 m ret cont
    | VarAssign (b, v, e) ->
      aux e n ret (fill_hole cont n (id, VarAssign (b, v, hole n)))
    | Unop (v, e) ->
      aux e n ret (fill_hole cont n (id, Unop (v, hole n)))
    | Binop (v, e1, e2) ->
      let m = fresh_hole_id () in
      let cont = aux e2 n ret (fill_hole cont n (id, Binop (v, hole m, hole n))) in
      let ret = fill_hole ret n (hole m) in
      aux e1 m ret cont
    | Call (e, args) ->
      let args = List.map (fun a -> (fresh_hole_id (),a)) args in
      let cont =
        (id, Call (hole n, args |> List.map (fun (m, (name,_)) -> (name, hole m))))
        |> fill_hole cont n in
      let cont = List.fold_left
        (fun cont (m,(_,e)) -> aux e m (fill_hole ret n (hole m)) cont)
        cont args in
      aux e n ret cont
    | Seq (e1,e2) ->
      let m = fresh_hole_id () in
      let ctx2 = id, Seq (hole m, hole n) in
      let cont = aux e2 n (fill_hole ret n ctx2) (fill_hole cont n ctx2) in
      let ret = fill_hole ret n (hole m) in
      aux e1 m ret cont
    | Return None -> fill_hole ret n (id, Const CNull)
    | Return (Some e) -> fill_hole ret n e
    | _ -> failwith "TODO"
  in
  let m = fresh_hole_id () in
  aux e m (hole m) (hole m)

(* Conversion to Mlsem AST *)

let typeof_const c =
  match c with
  | CChr _ -> Vecs.mk_singl Prim.chr
  | CDbl _ -> Vecs.mk_singl Prim.dbl
  | CLgl true -> Vecs.mk_singl Prim.tt
  | CLgl false -> Vecs.mk_singl Prim.ff
  | CNull -> Null.null

type varkind = VRef | VCst
let varinfo = Hashtbl.create 100
let mark_var v k =
  Hashtbl.replace varinfo v k
let var_mark v =
  match Hashtbl.find_opt varinfo v with None -> VCst | Some m -> m

let rec rem_n_first n lst =
  match n, lst with
  | 0, lst -> lst
  | _, [] -> []
  | n, _::lst -> rem_n_first (n-1) lst

let ellipsis_var = Variable.create_lambda (Some "...")

let rec aux_e (eid,e) =
  let rec aux e =
    match e with
    | Const c -> A.Value (typeof_const c |> GTy.mk)
    | Id v ->
      begin match var_mark v with
      | VCst -> A.Var v
      | VRef -> A.App ((Eid.unique (), A.Var Defs.unref), (Eid.unique (), A.Var v))
      end
    | Declare (v,e1,e2) ->
      mark_var v VRef ;
      let e1 =
        match e1 with
        | None -> Eid.unique (), A.Var Defs.uref
        | Some e1 ->
          Eid.unique (), A.App ((Eid.unique (), A.Var Defs.cref), (aux_e e1))
      in
      A.Let ([], v, e1, aux_e e2)
    | Let (v, e1, e2) ->
      mark_var v VCst ;
      A.Let ([], v, aux_e e1, aux_e e2)
    | VarAssign (_ (* TODO: superassign *), v, e) ->
      A.App ((Eid.unique (), A.Var Defs.setref),
        (Eid.unique (), A.Constructor (A.Tuple 2, [Eid.unique (), A.Var v; aux_e e])))
    | Unop (v,e) -> aux (Call ((Eid.unique (), Id v), [(Positional, e)]))
    | Binop (v,e1,e2) ->
      aux (Call ((Eid.unique (), Id v), [(Positional, e1);(Positional, e2)]))
    | Call (f, args) ->
      let rec parse_args args =
        match args with
        | [] -> 0,[],0,[]
        | (lbl,e)::args ->
          let (npos,named,nrem,es) = parse_args args in
          begin match lbl with
          | Positional when named=[] -> npos+1,named,nrem,e::es
          | Positional -> npos,named,nrem+1,e::es
          | Named lbl when nrem=0 -> npos,lbl::named,nrem,e::es
          | Named _ -> failwith "Unsupported arguments layout."
          end
      in
      let (npos,names,nrem,es) = parse_args args in
      let es = List.map aux_e es in
      let args = Eid.unique (), A.Constructor
        (CCustom { cdom=CArgs.cdom (npos,names,nrem) ; cons=CArgs.cons (npos,names,nrem) }, es) in
      A.App (aux_e f, args)
    | Ite (e, e1, e2) ->
      let e = aux_e e in
      let e = Eid.unique (), (A.App ((Eid.unique (), A.Var Defs.tobool), e)) in
      A.Ite (e, Ty.tt, aux_e e1, aux_e e2)
    | Function (ps, e) ->
      let has_ell = List.mem Ellipsis ps in
      let ps = ps |> List.filter_map (function
      | Ellipsis -> None
      | NoDefault v ->
        Some (v, None, TVar.mk TVar.KInfer None |> TVar.typ)
      | Default (v,e) ->
        Some (v, Some e, TVar.mk TVar.KInfer None |> TVar.typ)
      ) in
      let named = ps |> List.map (fun (v,o,ty) -> Variable.get_name v |> Option.get, o <> None, ty) in
      let add_let v def e =
        Eid.unique (), A.Let ([], v, (Eid.unique (), def), e)
      in
      let add_def e (v,o,ty) =
        match o with
        | Some e' ->
          add_let v (A.Constructor (A.Choice 2,
            [ Eid.unique (), A.Value (GTy.mk ty) ; aux_e e' ])) e
        | None -> add_let v (A.Value (GTy.mk ty)) e
      in
      let e = List.fold_left add_def (aux_e e) ps in
      let ellipsis, e =
        if has_ell then
          let ty = TVar.mk TVar.KInfer None |> TVar.typ in
          Some ty, add_let ellipsis_var (A.Value (GTy.mk ty)) e
        else None, e
      in
      let pty = CArgs.mk_from_def ([],named,ellipsis) in
      A.Lambda (GTy.mk pty, Variable.create_lambda None, e)
    | Seq (e1, e2) -> A.Let ([], Variable.create_gen None, aux_e e1, aux_e e2)
    | Return _ -> invalid_arg "Unsupported return statement."
    | Hole _ -> invalid_arg "Unsupported hole."
  in
  (eid, aux e)

let to_mlsem e = aux_e e
