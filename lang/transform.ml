open Ast
open Common
open R_types
open Types
open Sigs
module A = System.Ast
module C = System.Const

let typeof_const c =
  match c with
  | CChr _ -> Scalars.chr
  | CDbl _ -> Scalars.dbl
  | CLgl _ -> Scalars.lgl
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

let rec aux_e (eid,e) =
  let rec aux e =
    match e with
    | Const c -> A.Value (typeof_const c |> GTy.mk)
    | Id v ->
      begin match var_mark v with
      | VCst -> A.Var v
      | VRef -> A.App ((Eid.dummy, A.Var Defs.unref), (Eid.dummy, A.Var v))
      end
    | Declare (v,e1,e2) ->
      mark_var v VRef ;
      let e1 =
        match e1 with
        | None -> Eid.dummy, A.Var Defs.uref
        | Some e1 ->
          Eid.dummy, A.App ((Eid.dummy, A.Var Defs.cref), (aux_e e1))
      in
      A.Let ([], v, e1, aux_e e2)
    | Let (v, e1, e2) ->
      mark_var v VCst ;
      A.Let ([], v, aux_e e1, aux_e e2)
    | VarAssign (_ (* TODO: superassign *), v, e) ->
      A.App ((Eid.dummy, A.Var Defs.setref),
        (Eid.dummy, A.Constructor (A.Tuple 2, [Eid.dummy, A.Var v; aux_e e])))
    | Unop (v,e) -> aux (Call ((Eid.dummy, Id v), [(Positional 0, e)], FunInfo.unop))
    | Binop (v,e1,e2) ->
      aux (Call ((Eid.dummy, Id v), [(Positional 0, e1);(Positional 1, e2)], FunInfo.binop))
    | Call (f, args, finfo) ->
      let args = List.map (fun (lbl,e) -> lbl,e,Variable.create_gen None) args in
      let a = Eid.dummy, A.Value (Record.empty_closed |> GTy.mk) in
      let add_arg a (lbl, _, x) =
        let lbl = match lbl with
        | Positional i -> Args.id i
        | Named (i,l) -> Args.id (FunInfo.pos_of finfo (i,l))
        in
        let xe = Eid.dummy, A.Var x in
        Eid.dummy, A.Constructor (A.RecUpd lbl, [a; xe])
      in
      let add_ellipsis a args =
        let xs = args |> List.map (fun (_,_,x) -> Eid.dummy, A.Var x) in
        let ell = Eid.dummy, A.Constructor (A.Choice (List.length xs), xs) in
        let ell = Eid.dummy, A.Constructor (A.CCustom { cons=Ellipsis.cons ; cdom=Ellipsis.cdom }, [ell]) in
        Eid.dummy, A.Constructor (A.RecUpd Ellipsis.id, [a; ell])
      in
      let add_def e (_, def, x) =
        A.Let ([], x, aux_e def, (Eid.dummy, e))
      in
      let a = List.fold_left add_arg a args in
      let a = add_ellipsis a (rem_n_first finfo.num args) in
      let e = A.App (aux_e f, a) in
      List.fold_left add_def e args
    | Function (ps, e) ->
      let e = aux_e e in
      let v = Variable.create_lambda None in
      let ev = Eid.dummy, A.Var v in
      let add_def e p = match p with
      | Default _ -> failwith "TODO: default parameters"
      | NoDefault (i, v) ->
        Eid.dummy, A.Let ([], v, (Eid.dummy, A.Projection (A.Field (Args.id i), ev)), e)
      | Ellipsis -> failwith "TODO: ellipsis parameters"
      in
      let e = List.fold_left add_def e ps in
      A.Lambda (TVar.mk TVar.KInfer None |> TVar.typ |> GTy.mk, v, e)
    | Braced lst ->
      let seq e2 e1 =
        Eid.dummy, A.Let ([], Variable.create_gen None, aux_e e1, e2)
      in
      begin match List.rev lst with
      | [] -> A.Value (Ty.unit |> GTy.mk)
      | hd::lst -> List.fold_left seq (aux_e hd) lst |> snd
      end
  in
  (eid, aux e)

let to_mlsem e = aux_e e
