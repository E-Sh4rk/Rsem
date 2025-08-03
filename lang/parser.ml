open Tree_sitter_run
open Raw_tree
module A = PAst
open Common

let line_length = 0x10000
let conv_pos tspos =
  let bol = tspos.Loc.row*line_length in
  {
    Lexing.pos_fname = "" ;
    pos_lnum = tspos.Loc.row ;
    pos_bol = bol ;
    pos_cnum = bol + tspos.Loc.column ;
  }

(* let conv_loc tsloc =
  Position.lex_join (conv_pos tsloc.Loc.start) (conv_pos tsloc.end_) *)

let rec option_first lst =
  match lst with
  | [] -> None
  | (Some r)::_ -> Some r
  | None::lst -> option_first lst
let option_last lst = List.rev lst |> option_first
let start_loc_of_tree tree =
  let rec aux tree =
    match tree with
    | Token (loc, _) -> Some (conv_pos loc.start)
    | List lst -> List.map aux lst |> option_first
    | Tuple lst -> List.map aux lst |> option_first
    | Case (_, tree) -> aux tree
    | Option None -> None
    | Option (Some tree) -> aux tree
    | Any _ -> None
  in
  match aux tree with None -> Lexing.dummy_pos | Some p -> p
let end_loc_of_tree tree =
  let rec aux tree =
    match tree with
    | Token (loc, _) -> Some (conv_pos loc.end_)
    | List lst -> List.map aux lst |> option_last
    | Tuple lst -> List.map aux lst |> option_last
    | Case (_, tree) -> aux tree
    | Option None -> None
    | Option (Some tree) -> aux tree
    | Any _ -> None
  in
  match aux tree with None -> Lexing.dummy_pos | Some p -> p

let loc_of_tree tree =
  Position.lex_join
    (start_loc_of_tree tree)
    (end_loc_of_tree tree)

let extract2 tree =
  match tree with
  | Tuple [t1;t2] -> t1,t2
  | _ -> assert false
let extract3 tree =
  match tree with
  | Tuple [t1;t2;t3] -> t1,t2,t3
  | _ -> assert false
let extract4 tree =
  match tree with
  | Tuple [t1;t2;t3;t4] -> t1,t2,t3,t4
  | _ -> assert false

let aux_option f tree =
  match tree with
  | Option None -> None
  | Option (Some t) -> Some (f t)
  | _ -> assert false

let rec aux_prog tree =
  match tree with
  | Tuple [_ ; List lst] ->
    List.map aux_elt lst |> List.concat
  | _ -> assert false

and aux_elt tree =
  match tree with
  | Case (c, tree) -> aux_elt_case c tree
  | _ -> assert false

and aux_elt_case c tree =
  match c with
  | "Nl" | "Semi" -> []
  | "Exp" -> [aux_e tree]
  | _ -> assert false

and aux_e tree =
  let loc = loc_of_tree tree in
  match tree with
  | Case (c, tree) -> loc, aux_case c tree
  | _ -> assert false

and aux_case c tree =
  match c with
  | "Call" ->
    let t1,t2 = extract2 tree in
    let e1 = aux_e t1 in
    let e2 = aux_cargs t2 in
    A.Call (e1, e2)
  | "Id" -> A.Id (aux_tok tree)
  | "Str" -> A.Const (A.CStr (aux_string tree))
  | _ -> failwith ("TODO: "^c)

and aux_cargs tree =
  let _ (* open_paren *),t2,t3,_ (* close_paren *) = extract4 tree in
  (aux_carg t2)::(aux_cargs' t3)

and aux_carg tree =
  aux_option aux_arg tree

and aux_carg' tree =
  match tree with
  | Tuple [_ (* comma *) ; tree] -> aux_carg tree
  | _ -> assert false

and aux_cargs' tree =
  match tree with
  | List lst -> List.map aux_carg' lst
  | _ -> assert false

and aux_arg tree =
  match tree with
  | Case ("Arg_unna", tree) -> A.Unnamed (aux_e tree)
  | Case ("Arg_named", tree) ->
    let t1,_ (* = *),t3 = extract3 tree in
    let e = aux_option aux_e t3 in
    A.Named (aux_arg_id t1, e)
  | _ -> assert false

and aux_arg_id tree =
  match tree with
  | Case ("Choice_str", tree) -> A.ArgId (aux_param tree)
  | Case ("Null", _) -> A.NullId
  | _ -> assert false

and aux_param tree =
  match tree with
  | Case ("Str", tree) -> aux_string tree
  | Case ("Choice_dots", _) -> failwith "TODO: dots param"
  | _ -> assert false

and aux_string (* map_string_ *) tree =
  match tree with
  | Case ("Raw_str_lit", tok) -> aux_tok tok
  | Case ("Single_quoted_str", tree)
  | Case ("Double_quoted_str", tree) ->
    let _, tree, _ = extract3 tree in
    aux_quoted_string tree
  | _ -> assert false

and aux_quoted_string tree =
  match tree with
  | Option None -> failwith "TODO: none strings"
  | Option (Some tree) -> aux_quoted_string' tree
  | _ -> assert false

and aux_quoted_string' tree =
  match tree with
  | List lst -> List.map aux_quoted_string_elt lst |> String.concat ""
  | _ -> assert false

and aux_quoted_string_elt tree =
  match tree with
  | Case ("Pat_dc28280", tok) (* Simply quoted *) -> aux_tok tok
  | Case ("Pat_3a2a380", tok) (* Doubly quoted *) -> aux_tok tok
  | Case ("Esc_seq", _) -> failwith "TODO: escape seq"
  | _ -> assert false

and aux_tok tree  =
  match tree with
  | Token (_ (* loc *), str) -> str
  | _ -> assert false

let of_parser tree =
  Raw_tree.to_channel stdout tree ;
  aux_prog tree
