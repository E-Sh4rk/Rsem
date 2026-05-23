open Ast
open R_types
open Types
open Mlsem.Common
module GTy = Mlsem.Types.GTy
module TyScheme = Mlsem.Types.TyScheme
module MVariable = Mlsem.Lang.MVariable
module A = Mlsem.Lang.Ast
module SA = Mlsem.System.Ast
module TVar = Mlsem.Types.TVar
module RVar = Mlsem.Types.RVar

let typeof_const c =
  let open Builder in
  let e = match c with
  | CChr chr -> TVec (Vec.CstLength (1, PHat (PChr' chr)))
  | CDbl _ -> TVec (Vec.CstLength (1, PHat PDbl))
  | CInt i -> TVec (Vec.CstLength (1, PHat (PInt' (Some i, Some i))))
  | CClx _ -> TVec (Vec.CstLength (1, PHat PClx))
  | CLgl b -> TVec (Vec.CstLength (1, PHat (PLgl' b)))
  | CNull -> TNull
  in
  let b = TAttr { content=e ; classes=CNoClass } in
  Builder.build Builder.TIdMap.empty b
let typeof_const_comp c =
  let open Builder in
  let exact, ty = match c with
  | CChr chr -> true, TVec (Vec.CstLength (1, PHat (PChr' chr)))
  | CDbl _ -> false, TVec (Vec.CstLength (1, PHat PDbl))
  | CInt i -> true, TVec (Vec.CstLength (1, PHat (PInt' (Some i, Some i))))
  | CClx _ -> false, TVec (Vec.CstLength (1, PHat PClx))
  | CLgl b -> true, TVec (Vec.CstLength (1, PHat (PLgl' b)))
  | CNull -> true, TNull
  in
  exact, Builder.build Builder.TIdMap.empty ty

let typeof_expr env (_,e) =
  match e with
  | Const c -> Some (typeof_const c |> GTy.mk |> TyScheme.mk_mono)
  | Id v when MetaEnv.mem v env -> Some (MetaEnv.get_signature v env)
  | _ -> None
let labelof_expr env e =
  match snd e with
  | Const (CChr str) -> Some (Labels.Named str)
  (* | Const (CInt i) -> Some (Labels.Pos (i-1)) *)
  (* | Const (CDbl dbl) ->
    int_of_string_opt dbl |> Option.map (fun i -> Labels.Pos (i-1)) *)
  | _ -> (* If the expr is not a constant, we may still guess the label from its type *)
    begin match typeof_expr env e with
    | None -> None
    | Some ty ->
      let ty = TyScheme.get ty |> snd |> GTy.ub in
      begin match ty |> Attr.proj_content |> Vec.destruct with
      | [(CstLength (1, ty),_)] when Prim.is_singleton ty ->
        let ty = Prim.destruct ty in
        (* if Ty.leq ty Prim.Int.any then
          match Prim.Int.destruct ty with
          | false, [(Some i1, Some i2)] when i1=i2 -> Some (Labels.Pos (i1-1))
          | _ -> assert false
        else *)
        if Ty.leq ty Prim.Chr.any then
          match Prim.Chr.destruct ty with
          | false, { positive=true ; content=[str] } -> Some (Labels.Named str)
          | _ -> assert false
        else None
      | _ -> None
      end
    end
let typeof_fun env e args =
  let args = args |> List.map (fun (k,e) -> (k,Option.bind e (labelof_expr env))) in
  match snd e with
  | Id v when MetaEnv.mem v env -> Some (MetaEnv.get_fun_signature v args env)
  | _ -> typeof_expr env e

(* Arguments builder / Attr projector *)

module ArgBuilder = struct
  open Arg
  let split_at_index lst n =
    let rec aux acc next n =
      if n = 0 then List.rev acc, next
      else match next with
      | [] -> assert false
      | p::defs -> aux (p::acc) defs (n-1)
    in
    aux [] lst n
  let cons (pos,named,ell) lst =
    let rec extract_pos pos tys =
      match pos, tys with
      | [], tys -> [], tys
      | false::pos, tys ->
        let ps, tys = extract_pos pos tys in
        (Ty.F.mk_descr Ty.O.absent)::ps, tys
      | true::pos, ty::tys ->
        let ps, tys = extract_pos pos tys in
        (Ty.O.required ty |> Ty.F.mk_descr)::ps, tys
      | _, _ -> assert false
    in
    let rec extract_named named tys =
      match named, tys with
      | [], tys -> [], tys
      | (lbl, false)::named, tys ->
        let ns, tys = extract_named named tys in
        (lbl, Ty.F.mk_descr Ty.O.absent)::ns, tys
      | (lbl, true)::named, ty::tys ->
        let ns, tys = extract_named named tys in
        (lbl, Ty.O.required ty |> Ty.F.mk_descr)::ns, tys
      | _, _ -> assert false
    in
    let extract_ell ell tys =
      match ell, tys with
      | false, [] -> Ty.F.mk_descr Ty.O.absent
      | true, [ty] -> Ty.O.optional ty |> Ty.F.mk_descr
      | _, _ -> assert false
    in
    let pos', lst = extract_pos pos lst in
    let named', lst = extract_named named lst in
    let ell' = extract_ell ell lst in
    let pos_tl', named_tl' = ell', ell' in
    mk' {pos';named_tl';pos_tl';named'}
  let cdom (pos,named,ell) ty =
    let rec extract_pos pos tys =
      match pos, tys with
      | [], _ -> []
      | false::pos, _::tys -> extract_pos pos tys
      | false::pos, [] -> extract_pos pos []
      | true::pos, ty::tys ->
        (ty |> Ty.F.get_descr |> Ty.O.get |> Ty.O.Atom.get)::extract_pos pos tys
      | true::pos, [] -> Ty.any::extract_pos pos []
    in
    let rec extract_named named fields =
      match named with
      | [] -> []
      | (_, false)::named -> extract_named named fields
      | (lbl, true)::named when List.mem_assoc lbl fields ->
        (List.assoc lbl fields |> Ty.F.get_descr |> Ty.O.get |> Ty.O.Atom.get)::extract_named named fields
      | (_, true)::named -> Ty.any::extract_named named fields
    in
    let extract_ell ell ty =
      match ell with
      | false -> []
      | true -> [ty |> Ty.F.get_descr |> Ty.O.get |> Ty.O.Atom.get]
    in
    destruct ty
    |> List.filter_map (fun a ->
      let pos', named', ell' =
        match a with
        | DefSite { pos_named ; pos_tl ; named ; named_tl } ->
          (List.map snd pos_named), named@pos_named, Ty.F.cup pos_tl named_tl
        | CallSite { pos' ; pos_tl' ; named' ; named_tl' } -> pos', named', Ty.F.cup pos_tl' named_tl'
      in
      let args1 = extract_pos pos pos' in
      let args2 = extract_named named named' in
      let args3 = extract_ell ell ell' in
      let args = List.concat [args1 ; args2 ; args3] in
      let ty' = cons (pos,named,ell) args in
      if Ty.leq ty' ty then Some args else None
    )
end

module AttrProj = struct
  let pdom ty = Attr.mk_anyclass ty
  let proj ty = Attr.proj_content ty
end

module AttrConstr = struct
  let cons classes tys =
    match tys with
    | [ty] -> Attr.mk { content=ty ; classes }
    | _ -> assert false
  let cdom classes ty =
    Attr.destruct ty
    |> List.filter_map (fun (ps,_) ->
      let content = ps |> List.map (fun a -> a.Attr.content) |> Ty.conj in
      let ty' = Attr.mk { content ; classes } in
      if Ty.leq ty' ty then Some [content] else None
    )
end

(* Transformations *)

let recognize_const_comparison e =
  let f e =
    match e with
    | id, (Binop (v, e, (_, Const c)) | Binop (v, (_, Const c), e))
      when Variable.equal v Defs.BuiltinOp.eq ->
        let exact, ty = typeof_const_comp c in
        id, TyCheck { e ; ty ; sufficient=exact ; necessary=true }
    | id, (Binop (v, e, (_, Const c)) | Binop (v, (_, Const c), e))
      when Variable.equal v Defs.BuiltinOp.neq ->
        let exact, ty = typeof_const_comp c in
        id, TyCheck { e ; ty=Ty.neg ty ; sufficient=true ; necessary=exact }
    | e -> e
  in
  map f e

(* Conversion to Mlsem AST *)

let rec rem_n_first n lst =
  match n, lst with
  | 0, lst -> lst
  | _, [] -> []
  | n, _::lst -> rem_n_first (n-1) lst

let ellipsis_var = MVariable.create Immut (Some "...")

type cfg = { env : MetaEnv.t ; infer_mode : bool }

let to_mlsem (cfg:cfg) e =
  let rec aux (eid,e) =
    match e with
    | Const c -> eid, A.Value (typeof_const c |> GTy.mk)
    | Id v -> eid, A.Var v
    | Declare (v,e) -> eid, A.Declare (v, aux e)
    | Let (v, e1, e2) -> eid, A.Let ([], v, aux e1, aux e2)
    | VarAssign (v, e) -> eid, A.VarAssign (v, aux e)
    | Unop (v,e) -> aux (eid, Call ((Eid.unique (), Id v), [(Positional, Some e)]))
    | Binop (v,e1,e2) ->
      aux (eid, Call ((Eid.unique (), Id v), [(Positional, Some e1);(Positional, Some e2)]))
    | Call (f, args) ->
      let rec parse_args args =
        match args with
        | [] -> [],[],false,[]
        | (lbl,e)::args ->
          let (pos,named,ell,es) = parse_args args in
          begin match lbl,e with
          | MetaEnv.Positional, Some e -> true::pos,named,ell,e::es
          | MetaEnv.Positional, None -> false::pos,named,ell,es
          | Named lbl, Some e when pos=[] -> [],(lbl,true)::named,ell,e::es
          | Named lbl, None when pos=[] -> [],(lbl,false)::named,ell,es
          | Named _, _ -> failwith "Unsupported positional argument after a named one."
          | Ell, Some e when pos=[] && named=[] && not ell -> [],[],true,e::es
          | Ell, None when pos=[] && named=[] && not ell -> [],[],false,es
          | Ell, _ -> failwith "Unsupported argument after an ellipsis."
          end
      in
      let (pos,named,ell,es) = parse_args args in
      let es = List.map aux es in
      let arg = Eid.unique (), A.Constructor
        (CCustom { cname="cargs" ; cgen=true ; cdom=ArgBuilder.cdom (pos,named,ell) ; cons=ArgBuilder.cons (pos,named,ell) }, es) in
      let arg = Eid.unique (), A.Constructor (SA.Normalize, [arg]) in
      begin match typeof_fun cfg.env f args with
      | None ->
        let f = Eid.unique (), A.Projection
          (PCustom { pname="pfun" ; pgen=true ; pdom=AttrProj.pdom ; proj=AttrProj.proj }, aux f) in
        eid, A.App (f, arg)
      | Some ty when cfg.infer_mode ->
        let ty = TyUtils.proj_content ty in
        let tys = ty |> TyUtils.decompose_fun in
        (* tys |> List.iter (fun ty -> Format.printf "Alt: %a@." Mlsem_types.TyScheme.pp ty) ; *)
        let alts = tys |> List.map (fun ty ->
          Eid.refresh eid, A.Operation (SA.OCustom { oname="app" ; ofun=ty ; ogen=false }, arg)
          ) in
        begin match alts with
        | [] -> eid, A.Operation (SA.OCustom { oname="app" ; ofun=ty ; ogen=false }, arg)
        | a::alts -> List.fold_left (fun acc a -> Eid.unique (), A.Alt (a, acc)) a alts
        end
      | Some ty ->
        let ty = TyUtils.proj_content ty in
        eid, A.Operation (SA.OCustom { oname="app" ; ofun=ty ; ogen=false }, arg)
      end
    | Ite (e, e1, e2) ->
      let e = aux e in
      let e = Eid.unique (), (A.App ((Eid.unique (), A.Var Defs.tobool), e)) in
      eid, A.Ite (e, GTy.mk Defs.test_type, aux e1, aux e2)
    | While (e, e') ->
      let e = aux e in
      let e = Eid.unique (), (A.App ((Eid.unique (), A.Var Defs.tobool), e)) in
      eid, A.While (e, GTy.mk Defs.test_type, aux e')
    | For (None, e, e') ->
      let e, e' = aux e, aux e' in
      let e' = Eid.unique (), A.Voidify e' in
      let e' = Eid.unique (), A.Loop e' in
      eid, A.Seq (e, e')
    | For (Some v, e, e') ->
      let ev = MVariable.create Immut None in
      let e, e' = aux e, aux e' in
      let ev' = Eid.unique (), A.Var ev in
      let lkp = Eid.unique (), (A.App ((Eid.unique (), A.Var Defs.extract), ev')) in
      let assignment = Eid.unique (), A.VarAssign (v, lkp) in
      let e' = Eid.unique (), A.Seq (assignment, e') in
      let e' = Eid.unique (), A.Voidify e' in
      let e' = Eid.unique (), A.Loop e' in
      eid, A.Let ([], ev, e, e')
    | TyCheck {e;ty;necessary;sufficient} ->
      let e = aux e in
      let tt, ff = typeof_const (CLgl true) |> GTy.mk, typeof_const (CLgl false) |> GTy.mk in
      let bb = Eid.unique (), A.Value (GTy.cup tt ff) in
      let tt = Eid.unique (), A.Value (tt) in
      let ff = Eid.unique (), A.Value (ff) in
      eid, A.Ite (e, GTy.mk ty, (if sufficient then tt else bb), (if necessary then ff else bb))
    | Function (ps, e) ->
      let has_ell = List.mem Ellipsis ps in
      let rec treat_params ps =
        let ty = TVar.mk KInfer None |> TVar.typ |> Ty.O.required |> Ty.F.mk_descr in
        match ps with
        | [] -> [], []
        | Ellipsis::ps -> [], treat_params_nopos ps
        | (NoDefault v)::ps ->
          let pos, nopos = treat_params ps in
          (v, None, ty)::pos, nopos
        | (Default (v,e))::ps ->
          let pos, nopos = treat_params ps in
          let ty' = RVar.mk KInfer None |> RVar.fty in
          let ty' = Ty.F.cap ty' (Ty.O.absent |> Ty.F.mk_descr) in
          (v, Some e, Ty.F.cup ty ty')::pos, nopos
      and treat_params_nopos ps =
        let ty = TVar.mk KInfer None |> TVar.typ |> Ty.O.required |> Ty.F.mk_descr in
        match ps with
        | [] -> []
        | Ellipsis::_ -> failwith "Invalid parameter layout"
        | (NoDefault v)::ps ->
          (v, None, ty)::(treat_params_nopos ps)
        | (Default (v,e))::ps ->
          let ty' = RVar.mk KInfer None |> RVar.fty in
          let ty' = Ty.F.cap ty' (Ty.O.absent |> Ty.F.mk_descr) in
          (v, Some e, Ty.F.cup ty ty')::(treat_params_nopos ps)
      in
      let pos, nopos = treat_params ps in
      let pos_named = pos |> List.map (fun (v,_,ty) -> Variable.get_name v |> Option.get, ty) in
      let named = nopos |> List.map (fun (v,_,ty) -> Variable.get_name v |> Option.get, ty) in
      let add_let v def e =
        Eid.unique (), A.Let ([], v, (Eid.unique (), def), e)
      in
      let add_def e (v,o,fty) =
        let open Mlsem_types in
        let lbl = Labels.named (Variable.get_name v |> Option.get) |> Record.from_label in
        let ty = Record.mk' (FTy.of_oty (Ty.empty, true)) [lbl, fty] in
        let ty = Eid.unique (), A.Value (GTy.mk ty) in
        let e' = A.Projection (SA.PiFieldOpt lbl, ty) in
        match o with
        | Some e_default ->
          let e' = Eid.unique (), e' in
          let tau = Record.mk' (FTy.of_oty (Ty.empty, true)) [lbl, FTy.of_oty (Ty.any, false)] in
          let empty = Eid.unique (), A.Value (GTy.mk Ty.empty) in
          let e_default = Eid.unique (), A.Constructor (SA.Ternary tau, [ty ; empty ; aux e_default]) in
          let e' = A.Constructor (SA.Join 2, [ e'; e_default ]) in
          add_let v e' e
        | None -> add_let v e' e
      in
      let e = List.fold_left add_def (aux e) (pos@nopos) in
      let tl, e =
        if has_ell
        then
          let ty = TVar.mk KInfer None |> TVar.typ |> Ty.O.optional |> Ty.F.mk_descr in
          let ellty = Lst.mk {bindings=[];sym=[];tl=ty} |> Attr.mk_noclass in
          ty, add_let ellipsis_var (A.Value (GTy.mk ellty)) e
        else Ty.O.absent |> Ty.F.mk_descr, e
      in
      let pty = Arg.mk { named;pos_named;pos_tl=tl;named_tl=tl } in
      let lambda = Eid.unique (), A.Lambda ([], GTy.mk pty, MVariable.create Immut None, e) in
      eid, A.Constructor
        (CCustom { cname="cattr" ; cgen=true ; cdom=AttrConstr.cdom Classes.noclass ; cons=AttrConstr.cons Classes.noclass }, [lambda])
    | Seq (e1, e2) -> eid, A.Seq (aux e1, aux e2)
    | Return e -> eid, A.Return (match e with Some e -> aux e | None -> Eid.unique (), A.Void)
    | Break -> eid, A.Break | Next -> eid, A.Break
  in
  aux e

let to_mlsem cfg e =
  e |> recognize_const_comparison
    |> to_mlsem cfg
    |> Mlsem.Lang.Transform.transform
