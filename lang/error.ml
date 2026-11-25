(** Printing of the typing errors reported by MLsem (cf. [Mlsem.Lang.Error],
    which recognizes the failures of the encodings of MLsem's language, e.g.
    assignments).

    The errors are printed by MLsem's default printers; the witnesses are
    printed as R values by the printers registered by [Witnesses]. The
    failures of the [Alt] expressions that encode the applications of
    functions with declared signatures (cf. [Transform.alt_error]), which MLsem
    reports as [UntypeableEncoding] errors without details, are printed as the
    application errors they stand for.

    A declared signature that cannot be unified with the definition it annotates
    (cf. [sig_mismatch]) is reported before the definition is typed. *)

open Mlsem.Common
open Mlsem.Types
module Arg = Rstt.Arg
module SE = Mlsem.Lang.Error

(* How the details of an error are printed: with the types involved, with a
   witness of the failure (a value of the given type that is not of the
   expected one), or both. Set by the [-errors] flag. *)
let style = ref SE.Both

(* [err], with an [Alt] failure replaced by the application error it stands
   for (cf. [Transform.alt_error]). *)
let resolve err =
  match Transform.alt_error err with
  | Some (_, err) -> err
  | None -> err

(* The errors built by [sig_mismatch], indexed by their id: the signature and
   the type of the argument of the definition. *)
let mismatches : (GTy.t * GTy.t) Transform.EidTbl.t = Transform.EidTbl.create 16

(* The error of a definition [(eid, expr)] whose argument, of type [pty], cannot
   be unified with the one of its signature [decl] (as declared). *)
let sig_mismatch (eid, expr) decl pty : Mlsem.System.Error.t =
  let eid = Eid.refresh eid in
  Transform.EidTbl.replace mismatches eid (decl, pty) ;
  let given = GTy.map (fun pty -> Arrow.mk pty Ty.any) pty in
  let kind = Mlsem.System.Error.UntypeableCoercion { check=CheckStatic ; expected=decl ; given } in
  { eid ; expr ; kind ; env=Env.empty ; ann=Untyp }

let find_mismatch (err:SE.t) = Transform.EidTbl.find_opt mismatches err.eid

(* The header of a definition whose argument is of type [pty], as in R. *)
let pp_header fmt pty =
  match Arg.destruct (GTy.ub pty) with
  | [ DefSite { pos_named ; pos_tl ; named ; named_tl=_ } ] ->
    let has_ell = Sstt.Ty.F.(equiv pos_tl (mk_descr Sstt.Ty.O.absent)) |> not in
    let names = List.map fst pos_named
      @ (if has_ell then ["..."] else []) @ List.map fst named in
    Format.fprintf fmt "function(%s)" (String.concat ", " names)
  | _ | exception _ -> GTy.pp fmt pty

let title err =
  if find_mismatch err |> Option.is_some then "signature incompatible with the definition" else
  match Transform.alt_error err with
  | Some (name, _) -> "untypeable application of " ^ name
  | None -> SE.title err

(* The details of [err]. For a failed application of a function [name] with
   declared signatures, the type of the function is not printed: it is the
   intersection of all its signatures, which is often huge (e.g. [+]), and the
   witness is printed as a call of [name]. *)
let pp_descr ?name fmt (err:SE.t) =
  match name, err.kind with
  | Some name, UntypeableApp { fn ; arg } ->
    let pp_types fmt = Format.fprintf fmt "argument: @[<h>%a@]" Ty.pp arg in
    let pp_witness w fmt =
      Format.fprintf fmt "failing call: @[<hv>%a@]" (Witnesses.pp_call name) w in
    let witness =
      if Ty.leq fn Arrow.any then Ty.diff arg (Arrow.domain fn) |> Witness.of_ty
      else None in
    begin match !style, witness with
    | Types, _ | (Witnesses | Both), None -> pp_types fmt
    | Witnesses, Some w -> pp_witness w fmt
    | Both, Some w -> Format.fprintf fmt "%t@.%t" pp_types (pp_witness w)
    end
  | _, _ -> SE.pp_descr ~style:!style fmt err

(* The details of [err], if any. *)
let descr err =
  let d = match find_mismatch err, Transform.alt_error err with
    | Some (decl, pty), _ ->
      Format.asprintf "signature: @[<h>%a@]@.definition: @[<h>%a@]"
        GTy.pp decl pp_header pty
    | None, Some (name, err) -> Format.asprintf "%a" (pp_descr ~name) err
    | None, None -> Format.asprintf "%a" (pp_descr ?name:None) err
  in
  if d = "" then None else Some d
