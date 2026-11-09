(** Printing of witnesses (sample values) of R types as R values.

    MLsem extracts witnesses from the raw encoding of the types
    ({!Mlsem.Types.Witness}): the R values are tagged records (cf. Rstt).
    [register] installs a witness printer for each tag of an R value, which
    decodes the encoding back into R syntax, e.g. [structure(42L, class =
    "foo")] for the witness [attr({ _c = v({ _e = prim(int(i(42))) }) ;
    _class = class({ _foo = tt ; _ = ff }) ; _attr = lst({}) })]. *)

open Rstt
module W = Mlsem.Types.Witness
module Labels = Rstt.Labels

let fprintf = Format.fprintf

(* {1 Decoding of the encoding} *)

(* The field [lbl] of the record witness [w], if present. *)
let field lbl w =
  match w with
  | W.Record (bindings, tail) ->
    begin match List.find_opt (fun (l, _) -> Label.equal l lbl) bindings with
    | Some (_, W.Present w) -> Some w
    | Some (_, W.Absent) -> None
    | None -> (match tail with W.Present w -> Some w | W.Absent -> None)
    end
  | _ -> None

let enum_name = function W.Enum e -> Some (Enum.name e) | _ -> None

(* The type that a witness built from enums, intervals and records denotes,
   used to decode the classes with [Rstt.Classes.destruct]. *)
let rec to_ty w =
  match w with
  | W.Default -> Ty.any
  | Int z -> Intervals.Atom.mk_singl z |> Descr.mk_interval |> Ty.mk_descr
  | Enum e -> Descr.mk_enum e |> Ty.mk_descr
  | Tag (tag, w) -> Descr.mk_tag (tag, to_ty w) |> Ty.mk_descr
  | Record (bindings, tail) ->
    let to_f = function
      | W.Absent -> Ty.O.absent |> Ty.F.mk_descr
      | W.Present w -> Ty.O.required (to_ty w) |> Ty.F.mk_descr
    in
    let bindings = bindings |> List.map (fun (l, f) -> l, to_f f) |> LabelMap.of_list in
    { Records.Atom.bindings ; tail=to_f tail } |> Descr.mk_record |> Ty.mk_descr
  | EnumDefault | Tuple _ | TupleDefault | TagOpaque _ | TagDefault | Arrow -> raise Exit

(* {1 Printers} *)

let pp_seq pp fmt lst =
  Format.pp_print_list ~pp_sep:(fun fmt () -> fprintf fmt ",@ ") pp fmt lst

(* A primitive value, i.e. the content [w] of the witness [prim(w)]. Each
   component is a tag applied to its values, [na] standing for [NA]. *)
let pp_prim fmt w =
  match w with
  | W.Tag (comp, w) ->
    let na = enum_name w = Some "na" in
    begin match Tag.name comp, w with
    | "lgl", _ when na -> fprintf fmt "NA"
    | "int", _ when na -> fprintf fmt "NA_integer_"
    | "dbl", _ when na -> fprintf fmt "NA_real_"
    | "chr", _ when na -> fprintf fmt "NA_character_"
    | "clx", _ when na -> fprintf fmt "NA_complex_"
    | "raw", _ when na -> fprintf fmt "NA"
    | "lgl", Enum e -> fprintf fmt "%s" (if Enum.name e = "tt" then "TRUE" else "FALSE")
    | "int", Tag (_, Int z) -> fprintf fmt "%sL" (Z.to_string z)
    | "dbl", Tag (_, Int z) -> fprintf fmt "%s" (Z.to_string z)
    | "dbl", Enum _ -> fprintf fmt "0.5" (* A double that is not an integer *)
    | "chr", Tag (_, Enum e) ->
      let str = try Strings.string e with Not_found -> "abc" in
      fprintf fmt "%S" str
    | "chr", Tag (_, EnumDefault) -> fprintf fmt "%S" "abc"
    | "clx", _ -> fprintf fmt "0+1i"
    | "raw", _ -> fprintf fmt "as.raw(0)"
    | _, _ -> fprintf fmt "<%s>" (Tag.name comp)
    end
  | _ -> fprintf fmt "<prim>"

(* A vector [v(w)]: the record of its element, which is required, and of a
   tail that is absent for a scalar. A non-scalar is given two elements. *)
let pp_vec fmt w =
  match field Labels.Reserved.elt w, w with
  | Some e, W.Record (_, W.Absent) -> W.pp fmt e
  | Some e, _ -> fprintf fmt "@[<hv 2>c(%a,@ %a)@]" W.pp e W.pp e
  | None, _ -> fprintf fmt "c()"

(* The name of an R label, if it is one. *)
let label_info l = try Some (Labels.info l) with Invalid_argument _ -> None

(* The named fields of the record [w] (which must be R labels), followed by
   ["..."] if other fields may be present. *)
let pp_named_fields fmt w =
  match w with
  | W.Record (bindings, tail) ->
    let fields = bindings |> List.filter_map (fun (l, f) ->
        match label_info l, f with
        | Some (Labels.Named str), W.Present w -> Some (fun fmt -> fprintf fmt "%s = %a" str W.pp w)
        | Some (Labels.Pos i), W.Present w -> Some (fun fmt -> fprintf fmt "%i = %a" (i+1) W.pp w)
        | _, _ -> None) in
    let fields = match tail with
      | W.Present _ -> fields @ [fun fmt -> fprintf fmt "..."]
      | W.Absent -> fields in
    pp_seq (fun fmt pp -> pp fmt) fmt fields
  | _ -> fprintf fmt "..."

(* A list [lst(w)]: a record of its named elements. *)
let pp_lst fmt w = fprintf fmt "@[<hv 2>list(%a)@]" pp_named_fields w

(* The arguments [arg(w)] of a call: a record with the record of the positional
   arguments ([_pos]) and the one of the named arguments ([_named]). *)
let pp_arg fmt w =
  let positional = match field Labels.Reserved.pos w with
    | Some (W.Record (bindings, tail)) ->
      let args = bindings |> List.filter_map (fun (l, f) ->
          match label_info l, f with
          | Some (Labels.Pos i), W.Present w -> Some (i, fun fmt -> W.pp fmt w)
          | _, _ -> None)
        |> List.sort (fun (i, _) (j, _) -> compare i j) |> List.map snd in
      begin match tail with
      | W.Present w -> args @ [fun fmt -> W.pp fmt w]
      | W.Absent -> args
      end
    | _ -> []
  in
  let named = match field Labels.Reserved.named w with
    | Some (W.Record (bindings, _)) ->
      bindings |> List.filter_map (fun (l, f) ->
          match label_info l, f with
          | Some (Labels.Named str), W.Present w ->
            Some (fun fmt -> fprintf fmt "%s = %a" str W.pp w)
          | _, _ -> None)
    | _ -> []
  in
  fprintf fmt "@[<hv 1>(%a)@]" (pp_seq (fun fmt pp -> pp fmt)) (positional @ named)

(* The classes (not the method classes) that the witness [w] of the classes of
   a value features, and whether it may feature others. *)
let classes w =
  match w with
  | W.Tag (tag, w) ->
    begin try
      let { Classes.pos ; tail ; _ } =
        Descr.mk_tag (tag, to_ty w) |> Ty.mk_descr |> Classes.destruct in
      (* A method class [@m] that the classes listed do not imply (cf.
         [Classes.destruct]) stands for an unknown class with a method for
         [m]: it is printed as a placeholder, which is not valid R. *)
      let classes = pos |> List.map (fun (Classes.L (cls, _)) ->
          match cls with
          | Classes.Class c -> c
          | Method m -> Printf.sprintf "<class with a method for %s>" m) in
      let others = match tail with
        | Classes.Tail (PresentOr, _) -> true
        | Unknown | Tail ((AbsentOr | Exactly), _) -> false in
      classes, others
    with Exit | Invalid_argument _ | Not_found -> [], false
    end
  | _ -> [], false

(* A value with attributes [attr(w)]: a record of its content ([_c]), its
   classes ([_class]) and its other attributes ([_attr], a list). *)
let pp_attr fmt w =
  let content = field Labels.Reserved.content w |> Option.value ~default:W.Default in
  let classes, other_classes =
    field Labels.Reserved.classes w |> Option.fold ~none:([], false) ~some:classes in
  let attrs = match field Labels.Reserved.attrs w with
    | Some (W.Tag (_, (W.Record (bindings, _) as r)))
      when List.exists (function (_, W.Present _) -> true | _ -> false) bindings ->
      [fun fmt -> pp_named_fields fmt r]
    | _ -> []
  in
  let pp_content fmt w =
    match w with
    | W.Arrow -> fprintf fmt "function(...) NULL"
    | w -> W.pp fmt w
  in
  let classes = match classes, other_classes with
    | [], false -> []
    | [ c ], false -> [fun fmt -> fprintf fmt "class = %S" c]
    | cs, others ->
      let cs = List.map (Printf.sprintf "%S") cs @ (if others then ["..."] else []) in
      [fun fmt -> fprintf fmt "class = c(%s)" (String.concat ", " cs)]
  in
  match classes @ attrs with
  | [] -> pp_content fmt content
  | extra ->
    fprintf fmt "@[<hv 2>structure(%a,@ %a)@]" pp_content content
      (pp_seq (fun fmt pp -> pp fmt)) extra

(* The representative of the values that a type does not mention (e.g. the
   witness of [any \ vec1]). It should be unlikely to be excluded by the
   types: environments rarely appear in signatures. *)
let default = "new.env()"

let register () =
  let const str fmt _ = fprintf fmt "%s" str in
  let consts = [
    Null.tag, "NULL" ;
    Sym.tag, "quote(x)" ;
    Env.tag, "new.env()" ;
    Rstt.Lang.tag, "quote(f())" ;
    ExternalPtr.tag, "<externalptr>" ;
  ] in
  W.set_printer_params (
    [ W.Tagged (Attr.tag, pp_attr) ;
      Tagged (Vec.tag, pp_vec) ;
      Tagged (Prim.tag, pp_prim) ;
      Tagged (Lst.tag, pp_lst) ;
      Tagged (Arg.tag, pp_arg) ]
    @ List.map (fun (tag, str) -> W.Tagged (tag, const str)) consts
    @ List.map (fun (tag, str) -> W.Opaque (tag, str)) consts) ;
  W.set_default_printer default ;
  W.set_tag_default_printer default ;
  W.set_enum_default_printer default ;
  W.set_tuple_default_printer default

(* Prints the call of the function [name] with the arguments [w]. *)
let pp_call name fmt w =
  match w with
  | W.Tag (tag, w) when Tag.equal tag Arg.tag -> fprintf fmt "%s%a" name pp_arg w
  | w -> fprintf fmt "%s(%a)" name W.pp w
