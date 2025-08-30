
module type LazyTy = sig
  val name : string
end

module MakeLazy(L:LazyTy) = struct
  open Sstt
  let tag = Tag.mk' L.name (Tag.Monotonic { preserves_cap=true ; preserves_cup=false })

  let mk ty = (tag, ty) |> Descr.mk_tag |> Ty.mk_descr
  let extract_dnf comp = comp |> TagComp.dnf
  |> List.map (fun (ps,ns) -> List.map snd ps, List.map snd ns)
  let as_ty dnf = dnf |> List.map (fun (ps,_) -> Ty.conj ps) |> Ty.disj
  let dnf ty = ty |> Ty.get_descr |> Descr.get_tags |> Tags.get tag
    |> extract_dnf
  let proj ty = dnf ty |> as_ty
  let any = mk Ty.any

  let map f ty = f ty
    (* dnf |> List.map (fun (ps,ns) -> (List.map f ps, List.map f ns)) *)

  let to_t node ctx a =
    try
      let ty = extract_dnf a |> as_ty in
      Some (ty |> map (node ctx))
    with _ -> None

  let print_seq f sep =
    Format.(pp_print_list  ~pp_sep:(fun fmt () -> pp_print_string fmt sep) f)
  let print _ _ fmt t =
    Format.fprintf fmt "%s(%a)" L.name Printer.print_descr t

  let printer_builder = Printer.builder ~to_t ~map ~print
  let printer_params = Printer.{ aliases = []; extensions = [(tag, printer_builder)] }
end

module EllArg = MakeLazy(struct let name="..." end)
