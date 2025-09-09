open Lazy

type 'a cargs = 'a list (* Positionals *) * (string * 'a) list (* Named *) * 'a list (* Remaining *)
type 'a args = (bool * 'a) list (* Positionals *) * (string * bool * 'a) list (* Named *)
  * 'a (* Ellipsis *) * bool (* Opened *)
type 'a t = ('a args) list

open Sstt.Prec
open Sstt

let tag = Tag.mk "A"

let add_tag ty = Descr.mk_tag (tag, ty) |> Ty.mk_descr
let proj_tag ty = Ty.get_descr ty |> Descr.get_tags |> Tags.get tag
  |> Op.TagComp.as_atom |> snd

let id_of_pos pos = Format.asprintf ":%i" pos
let id_of_lbl lbl = lbl
let id_of_ell = ":..."
let lbl_of_ell = Types.Record.to_label id_of_ell
let id_of_posn = ":n"
let lbl_of_posn = Types.Record.to_label id_of_posn
let is_hidden_field name = String.starts_with ~prefix:":" name

let mk ?(allow_greater_posn=false) (args:Ty.t args) =
  let (pos, named, ell, o) = args in
  let ell = [(id_of_ell, (false, EllArg.mk ell))] in
  let posn = List.length pos |> Z.of_int in
  let posn = if allow_greater_posn then
      Types.Ty.interval (Some posn) None
    else
      Types.Ty.interval (Some posn) (Some posn)
  in
  let posn = [(id_of_posn, (false, posn))] in
  let pos = pos |> List.mapi (fun i (opt,ty) -> (id_of_pos i, (opt, Arg.mk ty))) in
  let named = named |> List.map (fun (lbl, opt, ty) -> (id_of_lbl lbl, (opt, Arg.mk ty))) in
  let bindings = List.concat [posn ; pos ; named ; ell] in
  Types.Record.mk o bindings |> add_tag

let mk_concrete (args:Ty.t cargs) =
  let (pos,named,rem) = args in
  let ell = List.concat [pos ; List.map snd named ; rem] |> Ty.disj in
  let pos = pos |> List.map (fun ty -> (false, ty)) in
  let named = named |> List.map (fun (lbl, ty) -> (lbl, false, ty)) in
  mk (pos,named,ell, false)

let split_at_index lst n =
  let rec aux acc next n =
    if n = 0 then List.rev acc, next
    else match next with
    | [] -> assert false
    | p::defs -> aux (p::acc) defs (n-1)
  in
  aux [] lst n

let mk_from_def (pos,named,ell) =
  let nn = List.length named in
  List.init (nn + 1) (fun i ->
    let pos', named = split_at_index named i in
    let pos = pos@(pos' |> List.map (fun (_,b,ty) -> (b,ty))) in
    mk ~allow_greater_posn:(i=nn) (pos,named,ell,true)
  ) |> Ty.disj

let map f t =
  t |> List.map (fun (pos,named,ell,o) ->
      (List.map (fun (o,ty) -> (o, f ty)) pos,
       List.map (fun (o,lbl,ty) -> (o, lbl, f ty)) named,
       f ell, o)
    )

let extract ty =
  Ty.get_descr ty |> Descr.get_records |> Op.Records.as_union |> List.map (fun comp ->
    let n = Records.Atom.find lbl_of_posn comp |> fst |> Ty.get_descr |> Descr.get_intervals
    |> Intervals.destruct |> List.hd |> Intervals.Atom.get |> fst in
    let n = match n with Some n -> Z.to_int n | None -> invalid_arg "Not an arg." in
    let pos = List.init n (fun n ->
      let name = id_of_pos n |> Types.Record.to_label in
      let (ty,o) = Records.Atom.find name comp in
      (o, Arg.proj ty)
    ) in
    let named = LabelMap.bindings comp.bindings |> List.filter_map (fun (lbl, (ty,o)) ->
      if is_hidden_field (Types.Record.from_label lbl)
      then None
      else Some (Types.Record.from_label lbl,o,Arg.proj ty)
    ) in
    let ell = Records.Atom.find (Types.Record.to_label id_of_ell) comp |> fst |> EllArg.proj in
    (pos,named,ell,comp.opened)
  )
let to_t node ctx comp =
  try
    let ty = Op.TagComp.as_atom comp |> snd in
    Some (extract ty |> map (node ctx))
  with Invalid_argument _ -> None

let destruct ty = ty |> proj_tag |> extract

let proj_arg (lbl, default) ty =
  let ty = proj_tag ty |> Ty.get_descr |> Descr.get_records in
  match Op.Records.proj (Types.Record.to_label lbl) ty with
  | (ty, true) -> Arg.proj ty |> Ty.cup default
  | (ty, false) -> Arg.proj ty

let proj_ellipsis ty =
  let ty = proj_tag ty |> Ty.get_descr |> Descr.get_records in
  match Op.Records.proj lbl_of_ell ty with
  | (_, true) -> assert false
  | (ty, false) -> EllArg.proj ty

let assume_posn ty n =
  let n = Z.of_int n in
  let n = Types.Ty.interval (Some n) (Some n) in
  let n = Types.Record.mk true [id_of_posn, (false, n)] in
  proj_tag ty |> Ty.get_descr |> Descr.get_records
  |> Op.Records.as_union |> List.filter (fun c ->
    let ty = Descr.mk_record c |> Ty.mk_descr in
    Ty.disjoint n ty |> not
  ) |> Op.Records.of_union |> Descr.mk_records |> Ty.mk_descr |> add_tag

let print_seq f sep =
  Format.(pp_print_list  ~pp_sep:(fun fmt () -> pp_print_string fmt sep) f)
let print prec assoc fmt t =
  let print_pos fmt (opt,ty) =
    if opt then
      Format.fprintf fmt "?(%a)" Printer.print_descr ty
    else
      Format.fprintf fmt "%a" Printer.print_descr ty
  in
  let print_named fmt (lbl,opt,ty) =
    let eq = if opt then ":?" else ":" in
    Format.fprintf fmt "%s%s%a" lbl eq Printer.print_descr ty
  in
  let print_line fmt (pos,named,ell,o) =
    Format.fprintf fmt "{{ %a ;; %a ;; %a %s}}"
      (print_seq print_pos " ; ") pos
      (print_seq print_named " ; ") named
      Printer.print_descr ell
      (if o then ".." else "")
  in
  let sym,_,_ as opinfo = varop_info Cup in
  fprintf prec assoc opinfo fmt "%a" (print_seq print_line sym) t

let printer_builder =
  Printer.builder ~to_t:to_t ~map:map ~print:print
let printer_params = Printer.{ aliases = []; extensions = [(tag, printer_builder)]}
let () = Types.Ty.add_printer_param printer_params
