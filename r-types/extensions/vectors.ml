open Sstt.Extensions
open Types

module Prim = struct
  let tt = Enum.define "tt" |> Enum.typ
  let ff = Enum.define "ff" |> Enum.typ
  let int = Enum.define "int" |> Enum.typ
  let lgl =
    let t = Ty.disj [tt;ff] in
    (* Enum.define "lgl" |> Enum.typ *)
    Ty.register "lgl" t ; t
  let dbl = Enum.define "dbl" |> Enum.typ
  let clx = Enum.define "clx" |> Enum.typ
  let chr = Enum.define "chr" |> Enum.typ
  let raw = Enum.define "raw" |> Enum.typ
  let any =
    let t = Ty.disj [int;lgl;dbl;clx;chr;raw] in
    Ty.add_printer_param { Sstt.Printer.aliases = [t, "prim"] ; Sstt.Printer.extensions = [] } ;
    t
end

module Vecs = struct (* TODO: do not use abstract types for the encoding but records *)
  let na = Enum.define "?" |> Enum.typ
  let tag = Abstracts.define "v" [Cov;Cov;Cov]
  let mk v n l =
    Abstracts.mk tag [Ty.cap v Prim.any; Ty.cap n na; Ty.cap l Ty.int]
  let mk_singl v = mk v Ty.empty (Ty.interval (Some Z.one) (Some Z.one))
  let any = mk Ty.any Ty.any Ty.any

  open Sstt.Prec
  open Sstt
  let print_seq f sep =
    Format.(pp_print_list  ~pp_sep:(fun fmt () -> pp_print_string fmt sep) f)
  let print prec assoc fmt t =
    let print_na fmt n =
      if Ty.is_empty n.Printer.ty
      then Format.fprintf fmt "!"
      else if Ty.equiv n.Printer.ty na
      then Format.fprintf fmt "?"
      else Format.fprintf fmt "<%a>" Printer.print_descr n
    in
    let print_atom fmt params =
      let p,na,i = match params with [p;na;i] -> p,na,i | _ -> assert false in
      Format.fprintf fmt "%a%a[%a](%a)" Tag.pp tag print_na na
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
    Printer.builder ~to_t:Abstracts.to_t ~map:Abstracts.map ~print:print
  let printer_params = Printer.{ aliases = []; extensions = [(tag, printer_builder)]}
  let () = Types.Ty.add_printer_param printer_params
end