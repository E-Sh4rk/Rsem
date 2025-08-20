
module type LazyTy = sig
  val name : string
end

module MakeLazy(L:LazyTy) = struct
  open Sstt
  let tag = Tag.mk L.name

  let add_tag ty = (tag, ty) |> Descr.mk_tag |> Ty.mk_descr
  let proj_tag ty = ty |> Ty.get_descr |> Descr.get_tags |> Tags.get tag
                    |> TagComp.as_atom |> snd

  let label = Label.mk "v"
  let pack ty =
    let bindings = LabelMap.singleton label (ty, true) in
    Descr.mk_record { Records.Atom.opened=true ; bindings } |> Ty.mk_descr |> add_tag
  let any = pack Ty.any

  let unpack ty =
    let pty = proj_tag ty in
    let atom = pty |> Ty.get_descr |> Descr.get_records |> Op.Records.approx in
    let (field_ty, opt) = Records.Atom.find label atom in
    if Ty.vars_toplevel pty |> VarSet.is_empty && atom.opened && opt then
      field_ty
    else
      invalid_arg "Malformed lazy type"

  let to_t node ctx ty =
    try
      if Ty.leq ty any |> not then raise Exit ;
      Some (unpack ty |> node ctx)
    with _ -> None

  let print _ _ fmt t =
    Format.fprintf fmt "%s(%a)" L.name Printer.print_descr t

  let map f l = f l

  let printer_builder = Printer.builder ~to_t ~map ~print
  let printer_params = Printer.{ aliases = []; extensions = [(tag, printer_builder)] }
end

module EllArg = MakeLazy(struct let name="..." end)
