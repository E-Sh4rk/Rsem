open Ast
open R_types
open Types
open Mlsem.Common
module A = Mlsem.Lang.Ast
module SA = Mlsem.System.Ast

let typeof_const c =
  match c with
  | CChr _ -> Vecs.mk_singl Prim.chr
  | CDbl _ -> Vecs.mk_singl Prim.dbl
  | CLgl true -> Vecs.mk_singl Prim.tt
  | CLgl false -> Vecs.mk_singl Prim.ff
  | CNull -> Null.null

(* Transformations *)

let recognize_const_comparison e =
  let f = function
  | id, (Binop (v, e, (_, Const c)) | Binop (v, (_, Const c), e))
    when Variable.equals v BuiltinOp.eq -> id, TyCheck (e, typeof_const c)
  | id, (Binop (v, e, (_, Const c)) | Binop (v, (_, Const c), e))
    when Variable.equals v BuiltinOp.neq -> id, TyCheck (e, typeof_const c |> Ty.neg)
  | e -> e
  in
  map f e

(* Conversion to Mlsem AST *)

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
    | Id v -> A.Var v
    | Declare (v,e) -> A.Declare (v, aux_e e)
    | Let (v, e1, e2) -> A.Let ([], v, aux_e e1, aux_e e2)
    | VarAssign (v, e) -> A.VarAssign (v, aux_e e)
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
        (CCustom { cgen=true ; cdom=CArgs.cdom (npos,names,nrem) ; cons=CArgs.cons (npos,names,nrem) }, es) in
      A.App (aux_e f, args)
    | Ite (e, e1, e2) ->
      let e = aux_e e in
      let e = Eid.unique (), (A.App ((Eid.unique (), A.Var Defs.tobool), e)) in
      A.Ite (e, Ty.tt, aux_e e1, aux_e e2)
    | TyCheck (e, ty) ->
      let e = aux_e e in
      let tt = Eid.unique (), A.Value (Vecs.mk_singl Prim.tt |> GTy.mk) in
      let ff = Eid.unique (), A.Value (Vecs.mk_singl Prim.ff |> GTy.mk) in
      A.Ite (e, ty, tt, ff)
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
          add_let v (A.Constructor (SA.Choice 2,
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
      A.Lambda ([], GTy.mk pty, Variable.create_lambda None, e)
    | Seq (e1, e2) -> A.Let ([], Variable.create_gen None, aux_e e1, aux_e e2)
    | Return e -> A.Return (match e with Some e -> aux_e e | None -> Eid.unique (), A.Void)
  in
  (eid, aux e)

let to_mlsem e =
  e |> recognize_const_comparison |> aux_e |> Mlsem.Lang.Transform.transform
