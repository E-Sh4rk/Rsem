(** Printing of the typing errors reported by MLsem.

    The errors are printed by MLsem's default printers, except the failures of
    the [Alt] expressions that encode the applications of functions with
    declared signatures (cf. [Transform.alt_error]): MLsem reports them as
    [UntypeableEncoding] errors, without details, and they are printed here as
    the application errors they stand for. *)

open Mlsem.Types
module SE = Mlsem.System.Error

(* How the details of an error are printed: with the types involved, or with a
   witness of the failure (a value of the given type that is not of the
   expected one). Set to [Witnesses] by the [-witnesses] flag. *)
let style = ref SE.Types

let title err =
  match Transform.alt_error err with
  | Some (name, _) -> "untypeable application of " ^ name
  | None -> SE.title err

(* The details of the failed application of [name] described by [err] (an
   [UntypeableApp] error). The type of the function is not printed: it is the
   intersection of all its signatures, which is often huge (e.g. [+]). *)
let pp_app_descr name fmt (err:SE.t) =
  match err.kind with
  | UntypeableApp { fn ; arg } ->
    let witness () =
      Ty.diff arg (Arrow.domain fn) |> Witness.of_ty in
    begin match !style, witness () with
    | SE.Witnesses, Some w ->
      Format.fprintf fmt "argument may be: @[<h>%a@]@.(not in the domain of %s)"
        Witness.pp w name
    | _ -> Format.fprintf fmt "argument: @[<h>%a@]" Ty.pp arg
    end
  | _ -> SE.pp_descr ~style:!style fmt err

(* The details of [err], if any. *)
let descr err =
  let d = match Transform.alt_error err with
    | Some (name, err) -> Format.asprintf "%a" (pp_app_descr name) err
    | None -> Format.asprintf "%a" (SE.pp_descr ~style:!style) err
  in
  if d = "" then None else Some d

(* [err], with an [Alt] failure replaced by the application error it stands
   for (cf. [Transform.alt_error]). *)
let resolve err =
  match Transform.alt_error err with
  | Some (_, err) -> err
  | None -> err
