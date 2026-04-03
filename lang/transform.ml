open Ast
open R_types
open Types
open Mlsem.Common
module GTy = Mlsem.Types.GTy
module MVariable = Mlsem.Lang.MVariable
module A = Mlsem.Lang.Ast
module SA = Mlsem.System.Ast
module TVar = Mlsem.Types.TVar

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
  | Id v when Env.mem v env -> Some (Env.find v env)
  | _ -> None

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
  let cons (npos,names,nrem) lst =
    let definite, rem = split_at_index lst (npos + (List.length names)) in
    assert (List.length rem = nrem) ;
    let tl' = Ty.disj rem |> Ty.O.optional |> Ty.F.mk_descr in
    let pos', named' = split_at_index definite npos in
    let pos' = List.map (fun ty -> ty |> Ty.O.required |> Ty.F.mk_descr) pos' in
    let named' = List.map2 (fun ty lbl -> lbl, ty |> Ty.O.required |> Ty.F.mk_descr) named' names in
    mk' {pos';tl';named'}
  let cdom (npos,names,nrem) ty =
    try
      destruct ty
      |> List.filter_map (fun a ->
        let pos, named, tl =
          match a with
          | DefSite { pos ; pos_named ; tl ; named } ->
            pos@(List.map snd pos_named), named@pos_named, tl
          | CallSite { pos' ; named' ; tl' } -> pos', named', tl'
        in
        let args1 = List.init npos (fun i -> if i < List.length pos then List.nth pos i else tl) in
        let args2 = List.map (fun name -> match List.assoc_opt name named with Some ty -> ty | None -> tl) names in
        let args3 = List.init nrem (fun _ -> tl) in
        let args = List.concat [args1 ; args2 ; args3] in
        let args = List.map (fun fty -> Ty.F.get_descr fty |> Ty.O.get) args in
        let ty' = cons (npos,names,nrem) args in
        if Ty.leq ty' ty then Some args else None
      )
    with Invalid_argument _ -> []
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
    try
      Attr.destruct ty
      |> List.filter_map (fun (ps,_) ->
        let content = ps |> List.map (fun a -> a.Attr.content) |> Ty.conj in
        let ty' = Attr.mk { content ; classes } in
        if Ty.leq ty' ty then Some [content] else None
      )
    with Invalid_argument _ -> []
end

(* Transformations *)

let recognize_const_comparison e =
  let f e =
    match e with
    | id, (Binop (v, e, (_, Const c)) | Binop (v, (_, Const c), e))
      when Variable.equal v BuiltinOp.eq ->
        let exact, ty = typeof_const_comp c in
        id, TyCheck { e ; ty ; sufficient=exact ; necessary=true }
    | id, (Binop (v, e, (_, Const c)) | Binop (v, (_, Const c), e))
      when Variable.equal v BuiltinOp.neq ->
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

type cfg = { env : Mlsem.Common.Env.t ; infer_mode : bool }

let to_mlsem (cfg:cfg) e =
  let rec aux (eid,e) =
    match e with
    | Const c -> eid, A.Value (typeof_const c |> GTy.mk)
    | Id v -> eid, A.Var v
    | Declare (v,e) -> eid, A.Declare (v, aux e)
    | Let (v, e1, e2) -> eid, A.Let ([], v, aux e1, aux e2)
    | VarAssign (v, e) -> eid, A.VarAssign (v, aux e)
    | Unop (v,e) -> aux (eid, Call ((Eid.unique (), Id v), [(Positional, e)]))
    | Binop (v,e1,e2) ->
      aux (eid, Call ((Eid.unique (), Id v), [(Positional, e1);(Positional, e2)]))
    | Call (f, args) ->
      let rec parse_args args =
        match args with
        | [] -> 0,[],0,[]
        | (lbl,e)::args ->
          let (npos,named,nrem,es) = parse_args args in
          begin match lbl with
          | MetaEnv.Positional -> npos+1,named,nrem,e::es
          | Named lbl when npos=0 -> 0,lbl::named,nrem,e::es
          | Named lbl -> 0,[lbl],nrem+npos+List.length named,e::es
          | Ell -> 0,[],nrem+npos+List.length named+1,e::es
          end
      in
      let (npos,names,nrem,es) = parse_args args in
      let es = List.map aux es in
      let args = Eid.unique (), A.Constructor
        (CCustom { cname="cargs" ; cgen=true ; cdom=ArgBuilder.cdom (npos,names,nrem) ; cons=ArgBuilder.cons (npos,names,nrem) }, es) in
      begin match typeof_expr cfg.env f with
      | None ->
        let f = Eid.unique (), A.Projection
          (PCustom { pname="pfun" ; pgen=true ; pdom=AttrProj.pdom ; proj=AttrProj.proj }, aux f) in
        eid, A.App (f, args)
      | Some ty when cfg.infer_mode ->
        let ty = TyUtils.proj_content ty in
        let tys = ty |> TyUtils.decompose_fun in
        (* tys |> List.iter (fun ty -> Format.printf "Alt: %a@." Mlsem_types.TyScheme.pp ty) ; *)
        let alts = tys |> List.map (fun ty ->
          Eid.refresh eid, A.Operation (SA.OCustom { oname="app" ; ofun=ty ; ogen=false }, args)
          ) in
        begin match alts with
        | [] -> eid, A.Operation (SA.OCustom { oname="app" ; ofun=ty ; ogen=false }, args)
        | a::alts -> List.fold_left (fun acc a -> Eid.unique (), A.Alt (a, acc)) a alts
        end
      | Some ty ->
        let ty = TyUtils.proj_content ty in
        eid, A.Operation (SA.OCustom { oname="app" ; ofun=ty ; ogen=false }, args)
      end
    | Ite (e, e1, e2) ->
      let e = aux e in
      let e = Eid.unique (), (A.App ((Eid.unique (), A.Var Defs.tobool), e)) in
      eid, A.Ite (e, GTy.mk Defs.test_type, aux e1, aux e2)
    | While (e, e') ->
      let e = aux e in
      let e = Eid.unique (), (A.App ((Eid.unique (), A.Var Defs.tobool), e)) in
      eid, A.While (e, GTy.mk Defs.test_type, aux e')
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
        match ps with
        | [] -> [], []
        | Ellipsis::ps -> [], treat_params_nopos ps
        | (NoDefault v)::ps ->
          let pos, nopos = treat_params ps in
          (v, None, TVar.mk KInfer None |> TVar.typ)::pos, nopos
        | (Default (v,e))::ps ->
          let pos, nopos = treat_params ps in
          (v, Some e, TVar.mk KInfer None |> TVar.typ)::pos, nopos
      and treat_params_nopos ps =
        match ps with
        | [] -> []
        | Ellipsis::_ -> failwith "Invalid parameter layout"
        | (NoDefault v)::ps ->
          (v, None, TVar.mk KInfer None |> TVar.typ)::(treat_params_nopos ps)
        | (Default (v,e))::ps ->
          (v, Some e, TVar.mk KInfer None |> TVar.typ)::(treat_params_nopos ps)
      in
      let pos, nopos = treat_params ps in
      let pos_named = pos |> List.map (fun (v,o,ty) -> Variable.get_name v |> Option.get,
        (if Option.is_none o then Ty.O.required ty else Ty.O.optional ty) |> Ty.F.mk_descr) in
      let named = nopos |> List.map (fun (v,o,ty) -> Variable.get_name v |> Option.get,
        (if Option.is_none o then Ty.O.required ty else Ty.O.optional ty) |> Ty.F.mk_descr) in
      let add_let v def e =
        Eid.unique (), A.Let ([], v, (Eid.unique (), def), e)
      in
      let add_def e (v,o,ty) =
        match o with
        | Some e' ->
          add_let v (A.Constructor (SA.Join 2,
            [ Eid.unique (), A.Value (GTy.mk ty) ; aux e' ])) e
        | None -> add_let v (A.Value (GTy.mk ty)) e
      in
      let e = List.fold_left add_def (aux e) (pos@nopos) in
      let tl, e =
        if has_ell
        then
          let ty = TVar.mk KInfer None |> TVar.typ |> Ty.O.optional |> Ty.F.mk_descr in
          let ellty = Lst.mk {pos=[];named=[];sym=[];tl=ty} |> Attr.mk_noclass in
          ty, add_let ellipsis_var (A.Value (GTy.mk ellty)) e
        else Ty.O.absent |> Ty.F.mk_descr, e
      in
      let pty = Arg.mk { pos=[];named;pos_named;tl } in
      let lambda = Eid.unique (), A.Lambda ([], GTy.mk pty, MVariable.create Immut None, e) in
      eid, A.Constructor
        (CCustom { cname="cattr" ; cgen=true ; cdom=AttrConstr.cdom Classes.noclass ; cons=AttrConstr.cons Classes.noclass }, [lambda])
    | Seq (e1, e2) -> eid, A.Seq (aux e1, aux e2)
    | Return e -> eid, A.Return (match e with Some e -> aux e | None -> Eid.unique (), A.Void)
    | Break -> eid, A.Break | Next -> eid, A.Break
  in
  aux e

let to_mlsem cfg e =
  e |> recognize_const_comparison |> to_mlsem cfg |> Mlsem.Lang.Transform.transform
