open Sstt.Extensions
open Types

module Prim = struct
  let int = Enum.define "int" |> Enum.typ
  let lgl = Enum.define "lgl" |> Enum.typ
  let dbl = Enum.define "dbl" |> Enum.typ
  let clx = Enum.define "clx" |> Enum.typ
  let chr = Enum.define "chr" |> Enum.typ
  let raw = Enum.define "raw" |> Enum.typ
  let any =
    let t = Ty.disj [int;lgl;dbl;clx;chr;raw] in
    Ty.add_printer_param { Sstt.Printer.aliases = [t, "prim"] ; Sstt.Printer.extensions = [] } ;
    t
end

module Vecs = struct
  let _na = Enum.define "?" |> Enum.typ
  let tag = Abstracts.define "v" [Cov;Cov;Cov]
  let mk v na l =
    let na = if na then _na else Ty.empty in
    Abstracts.mk tag [Ty.cap v Prim.any; na; Ty.cap l Ty.int]
  let mk_singl v = mk v false (Ty.interval (Some Z.one) (Some Z.one))
  let any = mk Ty.any true Ty.any

  open Sstt.Prec
  open Sstt
  let print_seq f sep =
    Format.(pp_print_list  ~pp_sep:(fun fmt () -> pp_print_string fmt sep) f)
  let print prec assoc fmt t =
    let print_atom fmt params =
      let p,na,i = match params with [p;na;i] -> p,na,i | _ -> assert false in
      Format.fprintf fmt "%a%s[%a](%a)" Tag.pp tag (if Ty.is_empty na.Printer.ty then "" else "?")
       Printer.print_descr i Printer.print_descr p
    in
    let print_lit prec assoc fmt (pos,params) =
      if pos then
        print_atom fmt params
      else
        let sym,_,_ as opinfo = unop_info Neg in
        fprintf prec assoc opinfo fmt "%s%a" sym print_atom params
    in
    let print_line prec assoc fmt (ps, ns) =
      let ps, ns = List.map (fun d -> true, d) ps, List.map (fun d -> false, d) ns in
      let sym,prec',_ as opinfo = varop_info Cap in
      fprintf prec assoc opinfo fmt "%s%s%a"
        (if ps = [] then Tag.name tag else "")
        (if ps = [] && ns <> [] then sym else "")
        (print_seq (print_lit prec' NoAssoc) sym) (ps@ns)
    in
    let sym,prec',_ as opinfo = varop_info Cup in
    fprintf prec assoc opinfo fmt "%a" (print_seq (print_line prec' NoAssoc) sym) t

  let printer_builder =
    Printer.builder ~to_t:(Abstracts.to_t tag) ~map:Abstracts.map ~print:print
  let printer_params = Printer.{ aliases = []; extensions = [(tag, printer_builder)]}
  let () = Types.Ty.add_printer_param printer_params
end