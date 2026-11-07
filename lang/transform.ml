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

(* The primitive component of the mode an [NA] belongs to. *)
let prim_of_na_kind = function
  | NaLgl -> Builder.PLgl | NaInt -> Builder.PInt | NaDbl -> Builder.PDbl
  | NaClx -> Builder.PClx | NaChr -> Builder.PChr

let na_ty kind =
  let open Builder in
  let p = prim_of_na_kind kind in
  TDiff (TVec (Vec.Scalar p), TVec (Vec.Scalar (PHat p)))

let typeof_const c =
  let open Builder in
  let pack t =
    Builder.build_struct Builder.TIdMap.empty t |> Attr.mk_content_noattr
  in
  let nopack t = Builder.build_struct Builder.TIdMap.empty t in
  match c with
  | CNan -> TVec (Vec.Scalar PDbl) |> pack
  | CNa kind -> na_ty kind |> pack
  | CChr chr -> TVec (Vec.Scalar (PChr' chr)) |> pack
  | CDbl str ->
    begin try
      let i = int_of_string str in
      TVec (Vec.Scalar (PDbl' (Some i, Some i))) |> pack
    with Failure _ -> TVec (Vec.Scalar PDbl) |> pack end
  | CInt i -> TVec (Vec.Scalar (PInt' (Some i, Some i))) |> pack
  | CClx _ -> TVec (Vec.Scalar PClx) |> pack
  | CLgl b -> TVec (Vec.Scalar (PLgl' b)) |> pack
  | CNull -> TNull |> nopack
let typeof_const_comp c =
  let open Builder in
  let exact, ty = match c with
  | CNan -> false, TVec (Vec.Scalar PDbl)
  | CNa kind -> true, na_ty kind
  | CChr chr -> true, TVec (Vec.Scalar (PChr' chr))
  | CDbl str ->
    begin try
      let i = int_of_string str in
      true, TVec (Vec.Scalar (PNum' (Some i, Some i)))
    with Failure _ -> false, TVec (Vec.Scalar PAny) end
  | CInt i -> true, TVec (Vec.Scalar (PNum' (Some i, Some i)))
  | CClx _ -> false, TVec (Vec.Scalar PAny)
  | CLgl b -> true, TVec (Vec.Scalar (PLgl' b))
  | CNull -> true, TNull
  in
  exact, Builder.build Builder.TIdMap.empty ty

let sigs_of_fun env e =
  match snd e with
  | Id v when MetaEnv.mem v env ->
    MetaEnv.get_signatures v env |> Option.map (fun sigs -> v, sigs)
  | _ -> None

(* The intersection of all the (resolved) signatures of a function (cf.
   [MetaEnv.all]), projected on their content. It is computed once for each
   set of signatures (they are compared physically), rather than for each
   application: intersecting the many signatures of a generic with
   class-overloads (e.g. [+]) is expensive. *)
let resolved_conj =
  let cache = ref [] in
  fun (sigs:MetaEnv.sigs) ->
    match List.assq_opt sigs !cache with
    | Some ty -> ty
    | None ->
      let ty = MetaEnv.all sigs |> List.map (GTy.map Rstt.Attr.proj_content) |> GTy.conj in
      cache := (sigs, ty)::!cache ; ty

(* [first_arg_has_class cls arg] tells whether the first positional argument
   of the call-site type [arg] certainly has the class [cls], i.e. whether it
   is a subtype of [<cls, ...>]. It does not for an argument whose type is a
   type variable: only one built with the class (e.g. ['a<cls>]) does. *)
let first_arg_has_class cls arg =
  let open Rstt in
  let classes = Classes.mk { pos=[Classes.L (Classes.Class cls, [])] ; neg=[] ; unk=[] ;
                             tail=Classes.Unknown } in
  let with_cls = Attr.mk { content=Ty.any ; classes ; attrs=Ty.any } in
  let has_class f = Ty.leq (Ty.F.get_descr f |> Ty.O.get |> fst) with_cls in
  match Arg.destruct arg with
  | [] -> false
  | atoms ->
    atoms |> List.for_all (function
      | Arg.CallSite { pos'=f::_ ; _ } -> has_class f
      | Arg.CallSite _ | Arg.DefSite _ -> false)
  | exception _ -> false

(* The partition of the call-site arguments of an application of the
   variable [v] following its dispatch, if it is a generic with class-overloads
   and its first positional argument [pos] (cf. [ArgBuilder]) is passed: the
   arguments whose first positional one is in each part of
   [MetaEnv.dispatch_partition]. Each part has as many positional arguments
   as the call ([pos]), as a call-site argument keeps track of their number
   (an argument passed but absent differs from none passed). It is empty
   otherwise. *)
let dispatch_partition env v pos =
  match Variable.get_name v, pos with
  | None, _ | _, ([] | false::_) -> []
  | Some name, true::pos ->
    (* The name of a variable of a namespace is prefixed with it. *)
    let name =
      match String.split_on_char ':' name |> List.rev with
      | name::""::_::_ -> name
      | _ -> name
    in
    let open Rstt in
    let opt_any = Ty.F.mk_descr (Ty.O.optional Ty.any) in
    let others = List.map (Fun.const opt_any) pos in
    MetaEnv.dispatch_partition name env |> List.map (fun p ->
      Arg.mk' { pos'=Ty.F.mk_descr (Ty.O.required p)::others ; pos_tl'=opt_any ;
                named'=[] ; named_tl'=opt_any })

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
      | false, [] -> let abs = Ty.F.mk_descr Ty.O.absent in abs, abs
      | true, [ty] ->
        let dnf = destruct ty in
        let pos = dnf |> List.map (function
          | DefSite { pos_named ; pos_tl ; _ } -> pos_tl::(List.map snd pos_named) |> Ty.F.disj
          | CallSite { pos' ; pos_tl' ; _ } -> pos_tl'::pos' |> Ty.F.disj
        ) |> Ty.F.disj in
        let named = dnf |> List.map (function
          | DefSite { pos_named ; named_tl ; named ; _ } ->
            named_tl::(List.map snd pos_named)@(List.map snd named) |> Ty.F.disj
          | CallSite { named' ; named_tl' ; _ } -> named_tl'::(List.map snd named') |> Ty.F.disj
        ) |> Ty.F.disj in
        pos, named
      | _, _ -> assert false
    in
    let pos', lst = extract_pos pos lst in
    let named', lst = extract_named named lst in
    let pos_tl', named_tl' = extract_ell ell lst in
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
      | true -> [ty]
    in
    destruct ty
    |> List.filter_map (fun a ->
      let pos', named', ell' =
        match a with
        | DefSite { pos_named ; pos_tl ; named ; named_tl } ->
          (List.map snd pos_named), named@pos_named,
            mk' { pos_tl'=pos_tl ; named_tl'=named_tl ; pos'=[] ; named'=[] }
        | CallSite { pos' ; pos_tl' ; named' ; named_tl' } -> pos', named',
            mk' { pos_tl' ; named_tl' ; pos'=[] ; named'=[] }
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
  let pdom ty = Attr.mk_content ty
  let proj ty = Attr.proj_content ty
end

module AttrConstr = struct
  let cons tys =
    match tys with
    | [ty] -> Attr.mk_content_noattr ty
    | _ -> assert false
  let cdom ty =
    Attr.destruct ty
    |> List.filter_map (fun (ps,_) ->
      let content = ps |> List.map (fun a -> a.Attr.content) |> Ty.conj in
      let ty' = Attr.mk_content_noattr content in
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

(* [e1 && e2] is [if (e1) (if (e2) TRUE else FALSE) else FALSE], and
   [e1 || e2] is [if (e1) TRUE else (if (e2) TRUE else FALSE)]: the inner [if]
   coerces [e2] to a logical scalar.
   Limitation: [NA] is not modelled. [tobool] maps it to [TRUE | FALSE], so e.g.
   [TRUE && NA] gets type [TRUE | FALSE] while R evaluates it to [NA]. *)
let encode_short_circuit e =
  let f e =
    let tt () = Eid.unique (), Const (CLgl true) in
    let ff () = Eid.unique (), Const (CLgl false) in
    let coerce e = Eid.unique (), Ite (e, tt (), ff ()) in
    match e with
    | id, Binop (v, e1, e2) when Variable.equal v Defs.BuiltinOp.and_ ->
      id, Ite (e1, coerce e2, ff ())
    | id, Binop (v, e1, e2) when Variable.equal v Defs.BuiltinOp.or_ ->
      id, Ite (e1, tt (), coerce e2)
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

let loop_body e =
  let e = Eid.unique (), A.Block (A.BLoop, e) in
  Eid.unique (), A.Loop e

(* Descriptions of the failure of the [Alt] expressions that encode the
   applications of overloaded functions, indexed by the id of the [Alt].
   MLsem reports such a failure as an [UntypeableEncoding] error, without
   details: they are recovered from this table (cf. [alt_error]). *)
module EidTbl = Hashtbl.Make(Eid)
let alt_errors : (Env.t -> string) EidTbl.t = EidTbl.create 256

(* The description of an [UntypeableEncoding] error raised on the [Alt]
   [eid] (or on one of its copies) under [env], if it encodes an application. *)
let alt_error eid env =
  Eid.eq_class eid |> Eid.Set.elements
  |> List.find_map (EidTbl.find_opt alt_errors)
  |> Option.map (fun f -> f env)

type cfg = { env : MetaEnv.t }

let to_mlsem (cfg:cfg) e =
  let rec aux (eid,e) =
    match e with
    | Const c -> eid, A.Value (typeof_const c |> GTy.mk)
    | Id v -> eid, A.Var v
    | Declare (v,e) -> eid, A.Declare (v, aux e)
    | Let (v, e1, e2) -> eid, A.Let ([Ty.any], v, aux e1, aux e2)
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
          | MetaEnv.Positional, Some e -> true::pos,named,ell,(MetaEnv.Positional,e)::es
          | MetaEnv.Positional, None -> false::pos,named,ell,es
          | Named lbl, Some e when pos=[] -> [],(lbl,true)::named,ell,(MetaEnv.Named lbl, e)::es
          | Named lbl, None when pos=[] -> [],(lbl,false)::named,ell,es
          | Named _, _ -> failwith "Unsupported positional argument after a named one."
          | Ell, Some e when pos=[] && named=[] && not ell -> [],[],true,(MetaEnv.Ell, e)::es
          | Ell, None when pos=[] && named=[] && not ell -> [],[],false,es
          | Ell, _ -> failwith "Unsupported argument after an ellipsis."
          end
      in
      let (pos,named,ell,args) = parse_args args in
      let es = args |> List.map snd |> List.map aux in
      (* Arg def is not generalized because it makes the Alt encoding slower. *)
      let arg_def = Eid.unique (), A.Constructor
        (CCustom { cname="cargs" ; cgen=false ;
          cdom=ArgBuilder.cdom (pos,named,ell) ;
          cons=ArgBuilder.cons (pos,named,ell) }, es) in
      (* let arg_def = Eid.unique (), A.Constructor (SA.Normalize, [arg_def]) in *)
      let varg = MVariable.create Immut None in
      let arg = Eid.unique (), A.Var varg in
      let e =
        match sigs_of_fun cfg.env f with
        | None -> (* First-class function *)
          let f = Eid.refresh (fst f), A.Projection
            (PCustom { pname="pfun" ; pgen=true ; pdom=AttrProj.pdom ; proj=AttrProj.proj }, aux f) in
          Eid.refresh eid, A.App (f, arg)
        | Some (v, sigs) -> (* Top-level function *)
          (* The application of a function with declared signatures (cf.
             [MetaEnv.sigs] for their kinds) is encoded as an alternative
             between:
             - in checking mode (no inference variable in the type of the
               argument, cf. [amask]), all the signatures at once: their
               intersection, i.e. base signatures, signatures of the methods,
               and default signature of the methods (plus the symbolic
               signatures, resolved for the type of the argument);
             - in inference mode, each signature alone: the base signatures,
               the default signature of the methods, and the signatures of
               the methods for the classes the first argument certainly has
               (cf. [first_arg_has_class]). The other methods are left out,
               the default signature standing for them: when the class of the
               argument is unknown (e.g. a type variable), considering all
               of them would make the inference blow up, the methods of a
               generic being many (e.g. [+]). The successful alternatives
               are intersected, so that the default signature only matters
               when no method applies.
             The default signature covers the values the base signatures do
             not apply to (cf. [MetaEnv.sigs]): an argument whose classes are
             unknown (e.g. [dbl]) is thus covered, its values of a class with a
             method being given the type [any]. *)
          let proj = GTy.map Rstt.Attr.proj_content in
          let arg_ty ?(v=varg) env =
            Env.find_opt v env |> Option.map (fun ts -> TyScheme.get ts |> snd |> GTy.ub) in
          (* The label variables of a symbolic signature are resolved using the
             type of the argument the function is applied to. *)
          let resolve_ty ?v env fsig =
            arg_ty ?v env |> Option.map (fun aty -> MetaEnv.resolve_signature aty fsig)
            |> Option.join |> Option.map proj
          in
          (* The signatures whose domain is disjoint from the type of the
             argument play no part in the application: they are left out of
             the intersection, which makes the applications of a generic with
             class-overloads to an argument of known class much faster. If
             none is left, the application fails: all are kept, for the
             error to be reported. *)
          let all_tys = MetaEnv.all sigs |> List.map proj in
          let resolved ?v env =
            let applicable =
              match arg_ty ?v env with
              | None -> all_tys
              | Some aty ->
                all_tys |> List.filter (fun ty ->
                  Ty.cap (GTy.lb ty |> Mlsem_types.Arrow.domain) aty |> Ty.is_empty |> not)
            in
            if List.length applicable = List.length all_tys || applicable = []
            then resolved_conj sigs
            else GTy.conj applicable
          in
          (* In checking mode, the argument is partitioned following the
             dispatch of the generic, if it is a method (cf.
             [MetaEnv.dispatch_partition]): the class of its first positional
             argument. Each part is typed apart, with only the signatures
             whose domain is not disjoint from it (cf. [resolved]), which
             avoids the intersection of all of them when the class of the
             argument is unknown (e.g. [dbl]). *)
          let partition = dispatch_partition cfg.env v pos in
          let varg' = if partition = [] then varg else MVariable.create Immut None in
          let alt_default =
            Eid.refresh eid, A.Operation (SA.OCustom { oname="app" ; ofun=(fun env ->
              let symbolic = MetaEnv.symbolic sigs |> List.map snd
                             |> List.filter_map (resolve_ty ~v:varg' env) in
              (resolved ~v:varg' env)::symbolic |> GTy.conj |> TyScheme.mk_poly
              ) ; ogen=false }, (Eid.unique (), A.Var varg'))
          in
          let alt_default =
            if partition = [] then alt_default
            else Eid.unique (), A.Let (partition, varg', arg, alt_default)
          in
          (* The alternatives of the inference mode, each with the class of the
             method it is a signature of (if any). *)
          let alt ofun = Eid.refresh eid, A.Operation (SA.OCustom { oname="app" ; ofun ; ogen=false }, arg) in
          let alt_ty ty = alt (Fun.const (proj ty |> TyScheme.mk_poly)) in
          let alts =
            (MetaEnv.base sigs@MetaEnv.methods_default sigs |> List.map (fun ty -> None, alt_ty ty))
            @(MetaEnv.methods_with_class sigs |> List.map (fun (cls, ty) -> Some cls, alt_ty ty))
            @(MetaEnv.symbolic sigs |> List.map (fun (cls, fsig) -> cls, alt (fun env ->
                resolve_ty env fsig |> Option.value ~default:GTy.any |> TyScheme.mk_poly)))
          in
          let amask env =
            let open Mlsem_types in
            let arg = if Env.mem varg env then Env.find varg env else TyScheme.mk_mono GTy.any in
            if MVarSet.subset (TyScheme.fv arg) (TVOp.all_vars KNoInfer)
            then true::List.map (Fun.const false) alts
            else
              let aty = TyScheme.get arg |> snd |> GTy.ub in
              false::(alts |> List.map (function
                | None, _ -> true
                | Some cls, _ -> first_arg_has_class cls aty))
          in
          let amask_default = true::List.map (Fun.const false) alts in
          let name = Format.asprintf "%a" Variable.pp v in
          let aerror env =
            let ty = Env.find varg env in
            Format.asprintf "application of %s failed\nargument is of type @[<h>%a@]" name TyScheme.pp ty
          in
          let settings = { SA.aname=name ; amask ; amask_default } in
          let alt_eid = Eid.refresh eid in
          EidTbl.replace alt_errors alt_eid aerror ;
          alt_eid, A.Alt (settings, alt_default::List.map snd alts)
      in
      eid, A.Let ([], varg, arg_def, e)
    | Ite (e, e1, e2) ->
      let e = aux e in
      let e = Eid.refresh (fst e), A.Operation (Defs.tobool_op, e) in
      eid, A.Ite (e, Defs.test_type, aux e1, aux e2)
    | While (e, e') ->
      let e = aux e in
      let e = Eid.refresh (fst e), A.Operation (Defs.tobool_op, e) in
      eid, A.While (e, Defs.test_type, aux e')
    | For (None, e, e') ->
      let e, e' = aux e, aux e' in
      let e' = loop_body e' in
      eid, A.Seq (e, e')
    | For (Some v, e, e') ->
      let ev = MVariable.create Immut None in
      let e, e' = aux e, aux e' in
      let ev' = Eid.unique (), A.Var ev in
      let lkp = Eid.refresh (fst e), A.Operation (Defs.extract_op, ev') in
      let assignment = Eid.refresh (fst e), A.VarAssign (v, lkp) in
      let e' = Eid.unique (), A.Seq (assignment, e') in
      let e' = loop_body e' in
      eid, A.Let ([Ty.any], ev, e, e')
    | Repeat e ->
      (* The body runs at least once, but a [Loop] (any number of times) is a
         sound approximation of it. *)
      eid, snd (loop_body (aux e))
    | TyCheck {e;ty;necessary;sufficient} ->
      let e = aux e in
      let tt, ff = typeof_const (CLgl true) |> GTy.mk, typeof_const (CLgl false) |> GTy.mk in
      let bb = Eid.unique (), A.Value (GTy.cup tt ff) in
      let tt = Eid.unique (), A.Value tt in
      let ff = Eid.unique (), A.Value ff in
      eid, A.Ite (e, ty, (if sufficient then tt else bb), (if necessary then ff else bb))
    | Function (ps, e) ->
      let has_ell = List.mem Ellipsis ps in
      let rec treat_params only_nopos ps =
        match ps with
        | [] -> [], []
        | Ellipsis::_ when only_nopos -> failwith "Invalid parameter layout"
        | Ellipsis::ps -> treat_params true ps
        | (NoDefault v)::ps ->
          let pos, nopos = treat_params only_nopos ps in
          let ty = TVar.mk KInfer (Variable.get_name v) |> TVar.typ |> Ty.O.required |> Ty.F.mk_descr in
          let res = (v, None, ty) in
          if only_nopos then pos, res::nopos else res::pos, nopos
        | (Default (v,e))::ps ->
          let pos, nopos = treat_params only_nopos ps in
          let ty = TVar.mk KInfer (Variable.get_name v) |> TVar.typ |> Ty.O.required |> Ty.F.mk_descr in
          let ty' = RVar.mk KInfer (Variable.get_name v) |> RVar.fty in
          let ty' = Ty.F.cap ty' (Ty.O.absent |> Ty.F.mk_descr) in
          let res = (v, Some e, Ty.F.cup ty ty') in
          if only_nopos then pos, res::nopos else res::pos, nopos
      in
      let pos, nopos = treat_params false ps in
      let pos_named = pos |> List.map (fun (v,_,ty) -> Variable.get_name v |> Option.get, ty) in
      let named = nopos |> List.map (fun (v,_,ty) -> Variable.get_name v |> Option.get, ty) in
      let add_let v def e =
        (* Generalizing default parameters may complexify the inference. *)
        let e = Eid.unique (), A.Constructor (SA.NoGen, [e]) in
        Eid.unique (), A.Let ([Ty.any], v, (Eid.unique (), def), e)
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
          let exc = Eid.unique (), A.Exc in
          let e_default = Eid.unique (),
          A.Constructor (SA.Ternary tau, [ty ; exc ; aux e_default]) in
          let e' = A.Constructor (SA.Join 2, [ e'; e_default ]) in
          add_let v e' e
        | None -> add_let v e' e
      in
      (* The first parameter is bound outermost: a default value can refer to
         the parameters before it ([function(x, r = range(x))]). *)
      let e = List.fold_right (fun p e -> add_def e p) (pos@nopos) (aux e) in
      let pos_tl, named_tl, e =
        if has_ell
        then
          let pos_tl = TVar.mk KInfer (Some "_ell") |> TVar.typ |> Ty.O.optional |> Ty.F.mk_descr in
          let named_tl = RVar.mk KInfer (Some "_ell") |> RVar.fty in
          (* [...] never holds a named argument matching a formal: excluding them keeps
             the named part of [ellty] depending on [named_tl] at the same labels as [pty]. *)
          let named' = (pos_named@named) |> List.map (fun (str,_) -> str, Ty.F.mk_descr Ty.O.absent) in
          let ellty = Arg.mk' {pos'=[];named';pos_tl'=pos_tl;named_tl'=named_tl} in
          pos_tl, named_tl, add_let ellipsis_var (A.Value (GTy.mk ellty)) e
        else let abs = Ty.F.mk_descr Ty.O.absent in abs, abs, e
      in
      let pty = Arg.mk { named;pos_named;pos_tl;named_tl } in
      let lambda = Eid.refresh eid, A.Lambda ([], Some (GTy.mk pty), MVariable.create Immut None, e) in
      eid, A.Constructor
        (CCustom { cname="cattr" ; cgen=true ; cdom=AttrConstr.cdom ; cons=AttrConstr.cons }, [lambda])
    | Seq (e1, e2) -> eid, A.Seq (aux e1, aux e2)
    | Return e -> eid, A.Return (match e with Some e -> aux e | None -> Eid.unique (), A.Void)
    | Local e ->
      (* Neither [return] nor [break]/[next] cross it: [break] and [next] are an
         error there, which the [BLoop] block makes them (they yield no value). *)
      let e = Eid.unique (), A.Block (A.BLoop, aux e) in
      eid, A.Block (A.BFun, e)
    | Break -> eid, A.Break | Next -> eid, A.Break
    | Dots -> eid, A.Var ellipsis_var
    | DotsN _ ->
      let e = Eid.unique (), A.Var ellipsis_var in
      eid, (A.Operation (Defs.flattell_op, e))
  in
  aux e

let to_mlsem cfg e =
  e |> recognize_const_comparison
    |> encode_short_circuit
    |> to_mlsem cfg
    |> Mlsem.Lang.Transform.transform
