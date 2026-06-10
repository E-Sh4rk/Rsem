open Mlsem.Common
module MVariable = Mlsem.Lang.MVariable
open Lang
open Tree_sitter_r
open R_types
module System = Mlsem.System
open Mlsem.Types

(* let () =
  Tree_sitter_run.Main.run
    ~lang:"r"
    ~parse_source_file:Parse.parse_source_file
    ~parse_input_tree:Parse.parse_input_tree
    ~dump_tree:Boilerplate.dump_tree
    ~dump_extras:Boilerplate.dump_extras *)

(* PARAMETERS *)
let record = ref false
let input_files = ref []
let gradual = ref false
(* ========== *)

module StrMap = Map.Make(String)

let refresh_vars kind ty =
  let drop1 str = String.sub str 1 (String.length str - 1) in
  let vars = TVOp.vars ty in
  let s1 = MVarSet.elements1 vars
  |> List.map (fun tv -> tv, TVar.mk kind (Some (Sstt.Var.name tv |> drop1)) |> TVar.typ) in
  let s2 = MVarSet.elements2 vars
  |> List.map (fun rv -> rv, RVar.mk kind (Some (Sstt.RowVar.name rv |> drop1)) |> Row.id_for) in
  let s = Subst.of_list s1 s2 in
  Subst.apply s ty
let sigs_of_ty ty =
  let fun_sig = ref false in
  let aux ty =
    match Arrow.dnf ty with
    | [arrs] ->
      fun_sig := true ;
      arrs |> List.map
        (fun (a,b) ->
          let a = Rstt.Arg.reidentify ~id:(TVar.mk KInfer None |> TVar.typ) a in
          Arrow.mk a b
        )
    | _ -> [ty]
  in
  let aux_p { Rstt.Attr.content ; classes ; attrs } =
    aux content |> List.map (fun content -> Rstt.Attr.mk {Rstt.Attr.content ; classes ; attrs})
  in
  let aux_n a = [Rstt.Attr.mk a |> Ty.neg] in
  let aux (ps, ns) =
    (List.concat_map aux_n ns)@(List.concat_map aux_p ps)
  in
  let aux ty =
    match Rstt.Attr.destruct ty with
    | [line] -> aux line
    | _ -> [ty]
  in
  let ty = refresh_vars KNoInfer ty in
  let sigs = aux ty in
  (!fun_sig, sigs, GTy.mk ty |> TyScheme.mk_poly)
let extend_env mlast env =
  if !gradual then
    let fv = System.Ast.fv mlast in
    let dom = Env.domain env |> VarSet.of_list in
    let missing = VarSet.diff fv dom in
    missing |> VarSet.elements |> List.fold_left
      (fun env v -> Env.add v (TyScheme.mk_mono GTy.dyn) env) env
  else
    env

type typing_ctx = { idenv: Variable.t StrMap.t ; tenv: MetaEnv.t ; senv: Ty.t list VarMap.t ;
                    benv: Rstt.Builder.env ; tidenv: Ty.t Rstt.Builder.TIdMap.t }
let initial_ctx = { benv=Rstt.Builder.empty_env ; tidenv=Rstt.Builder.TIdMap.empty ;
                    idenv=StrMap.empty ; tenv=MetaEnv.initial ; senv=VarMap.empty }

let infer ctx mlast =
  let env = MetaEnv.env ctx.tenv |> extend_env mlast in
  let renvs = System.Refinement.refinements env mlast in
  (* REnvSet.elements renvs |> List.iter (fun renv -> Format.printf "Renv: %a@." REnv.pp renv) ; *)
  let anns = System.Reconstruction.infer
    ~direct_narrowing:true ~partition_narrowing:true env renvs mlast in
  let tvs, ty = System.Checker.typeof_def env anns mlast |> TyScheme.get in
  TyScheme.mk tvs (GTy.ub ty |> GTy.mk)

let treat_ast v ctx ast =
  try
    let ctx = match VarMap.find_opt v ctx.senv with
    | None ->
      let mlast = Transform.to_mlsem { env=ctx.tenv ; infer_mode=true } ast in
      (* Format.printf "%a@.@." System.Ast.pp mlast ; *)
      let ty = infer ctx mlast in
      { ctx with tenv=MetaEnv.replace_signature v ty ctx.tenv }
    | Some sigs ->
      let mlast = Transform.to_mlsem { env=ctx.tenv ; infer_mode=false } ast in
      (* Format.printf "%a@.@." System.Ast.pp mlast ; *)
      let asts = List.map (fun s -> Mlsem_system.Ast.coerce CheckStatic (GTy.mk s) mlast) sigs in
      let _ = List.map (infer ctx) asts in
      ctx
    in
    let ty = MetaEnv.get_signature v ctx.tenv in
    Format.printf "%a:@? @[%a@]@.@." Variable.pp v TyScheme.pp_short ty ;
    ctx
  with System.Checker.Untypeable (err) ->
    Format.printf "Untypeable: %s@." err.title ;
    err.descr |> Option.iter (Format.printf "%s@.") ;
    Format.printf "@." ; ctx

let dummy_var = Variable.create (Some "_")
let treat_def ctx past =
  let (eid,ast) = PAst.transform
    { PAst.id = Scope.from_toplevel (MetaEnv.env ctx.tenv) ctx.idenv } past in
  (* Format.printf "%a@.@." Ast.pp_e (id,ast) ; *)
  match ast with
  | VarAssign (v, e) ->
    (* TODO: If v is a fresh Immut var (if no add_sig before), add it to the idenv *)
    treat_ast v ctx e
  | _ -> treat_ast dummy_var ctx (eid, ast)

let add_sig ctx str tye =
  let open R_types.Types in
  let open Mlsem_common in
  let benv, ty = Builder.resolve ctx.benv tye in
  let ty = ty |> Builder.build ctx.tidenv in
  let fun_sig,s,ty = sigs_of_ty ty in
  let v,s =
    match StrMap.find_opt str ctx.idenv with
    | Some v when fun_sig -> (* Overload *)
      let s =
        if VarMap.mem v ctx.senv
        then (VarMap.find v ctx.senv)@s
        else s
      in
      v,s
    | None | Some _ -> (* Redefinition (shadowing) *)
      let v =
        if fun_sig
        then MVariable.create Immut (Some str)
        else
          let tvs, ty = TyScheme.get ty in
          if MixVarSet.is_empty tvs |> not then failwith "Non-functional signatures cannot have type variables" ;
          MVariable.create (AnnotMut ty) (Some str)
      in
      v,s
  in
  let idenv = StrMap.add str v ctx.idenv in
  (* Format.printf "Adding %s: @[%a@]@." str TyScheme.pp ty ; *)
  (* Format.printf "Adding %s: @[%a@]@." str Sstt.Printer.print_ty'
    (TyScheme.get ty |> snd |> GTy.ub) ; *)
  let tenv = MetaEnv.add_signature v ty ctx.tenv in
  let senv = VarMap.add v s ctx.senv in
  { benv ; idenv ; tenv ; senv ; tidenv=ctx.tidenv }

let add_alias ctx str tye =
  let open R_types.Types in
  let benv, ty = Builder.resolve ctx.benv tye in
  let tid = Builder.TId.create () in
  let benv = { benv with tids=Builder.StrMap.add str tid benv.tids } in
  let ctx = { ctx with benv } in
  let ty = ty |> Builder.build ctx.tidenv in
  let ctx = { ctx with tidenv=Builder.TIdMap.add tid ty ctx.tidenv } in
  PEnv.register str ty ; ctx

let add_def ctx def =
  match def with
  | Sigs.Sig (str, tye) -> add_sig ctx str tye
  | Sigs.Alias (str, tye) -> add_alias ctx str tye

let treat_extra ctx extra =
  match extra with
  | `Comment (_loc, (_, str)) ->
    if String.starts_with ~prefix:"##" str then
      let str = String.sub str 2 ((String.length str) - 2) in
      let def = IO.parse_def str in
      add_def ctx def
    else ctx


(* ===== COMMAND LINE ===== *)

let usage_msg = "rsem [-record] [-gradual] <file1> [<file2>] ..."
let anon_fun filename =
    input_files := filename::!input_files
let speclist =
    [
      ("-record", Arg.Set record, "Record tallying instances into a file") ;
      ("-gradual", Arg.Set gradual, "Give the dyn type to undefined functions")
    ]

let snf _ cs = cs |> List.filter_map Rstt.TyOp.normalize_subst
let main (ctx, fn) =
  let res = Parse.file fn in
  match res.program with
  | None -> ctx
  | Some prog ->
    (* Boilerplate.dump_extras res.extras ; *)
    let ctx = List.fold_left treat_extra ctx res.extras in
    let tree = Boilerplate.map_program () prog in
    let prog = Parser.of_parser tree in
    (* Format.printf "%a@.@." PAst.pp prog ; *)
    List.fold_left treat_def ctx prog

let () =
  Printexc.record_backtrace true ;
  Mlsem_types.PrinterCfg.set_descr_printer Rstt.Pp.print_descr_ctx ;
  Mlsem_types.PrinterCfg.set_printer Rstt.Pp.print ;
  Mlsem_types.PrinterCfg.add_printer_param (Rstt.Pp.printer_params ()) ;
  Mlsem_system.Config.normalization_fun := Fun.id ;
  Mlsem_system.Config.subst_normalization_fun := snf ;
  Mlsem.Lang.Config.void_ty := Transform.typeof_const CNull ;
  (* System.Config.infer_overload := false ; *)

  Arg.parse speclist anon_fun usage_msg ;
  if !record then Recording.start_recording () ;

  let ctx, penv = ref initial_ctx, ref PEnv.empty in
  List.rev !input_files |> List.iter (fun fn ->
      Format.printf "@.@{<bold>===== Processing %s =====@}@." fn ;
      Recording.clear () ;
      let ctx', penv' = PEnv.sequential_handler !penv main (!ctx, fn) in
      ctx := ctx' ; penv := penv' ;
      if !record then Recording.save_to_file fn (Recording.tally_calls ())
  )
