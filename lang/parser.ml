open Tree_sitter_run
open Raw_tree
module A = PAst
open Mlsem.Common

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
let extract5 tree =
  match tree with
  | Tuple [t1;t2;t3;t4;t5] -> t1,t2,t3,t4,t5
  | _ -> assert false
let extract7 tree =
  match tree with
  | Tuple [t1;t2;t3;t4;t5;t6;t7] -> t1,t2,t3,t4,t5,t6,t7
  | _ -> assert false
let extract8 tree =
  match tree with
  | Tuple [t1;t2;t3;t4;t5;t6;t7;t8] -> t1,t2,t3,t4,t5,t6,t7,t8
  | _ -> assert false

let aux_option f tree =
  match tree with
  | Option None -> None
  | Option (Some t) -> Some (f t)
  | _ -> assert false

let rec aux_prog tree =
  match tree with
  | Tuple [_ ; elts] -> aux_elts elts
  | _ -> assert false

and aux_elts tree =
  match tree with
  | List lst -> List.map aux_elt lst |> List.concat
  | _ -> assert false

and aux_elt (* map_anon_choice_arg_value_c460aa0 *) tree =
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
  | "Float" -> A.Const (A.CFloat (aux_float tree))
  | "Inf" -> A.Const (A.CFloat "Inf")
  | "True" -> A.Const (A.CBool true)
  | "False" -> A.Const (A.CBool false)
  | "Null" -> A.Const (A.CNull)
  | "Un_op" ->
    let op, arg = aux_unary tree in
    A.Unop (op, arg)
  | "Bin_op" ->
    let op, arg = aux_binary tree in
    A.Binop (op, arg)
  | "Func_defi" ->
    let k,_,params,_,e = extract5 tree in
    let k = aux_fkind k in
    let params = aux_params params in
    let e = aux_e e in
    A.Function (k, params, e)
  | "Braced_exp" ->
    let _, es, _ = extract3 tree in
    A.Braced (aux_elts es)
  | "If_stmt" ->
    let _,_,_,e,_,_,e1,e2 = extract8 tree in
    A.Ite (aux_e e, aux_e e1, aux_else e2)
  | "While_stmt" ->
    let _,_,_,e,_,_,e' = extract7 tree in
    A.While (aux_e e, aux_e e')
  | "Ret" -> A.Return | "Brk" -> A.Break | "Next" -> A.Next
  | _ -> failwith ("TODO: "^c)

and aux_else tree =
  match tree with
  | Option None -> None
  | Option (Some tree) ->
    let _, _, e = extract3 tree in
    Some (aux_e e)
  | _ -> assert false

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
  | Case ("Choice_str", tree) -> aux_param tree
  | Case ("Null", _) -> A.NullId
  | _ -> assert false

and aux_param tree =
  match tree with
  | Case ("Str", tree) -> A.ArgId (aux_string tree)
  | Case ("Choice_dots", tree) -> aux_param_name tree
  | _ -> assert false

and aux_params (* map_parameters *) tree =
  let (_,params,_) = extract3 tree in
  match params with
  | Option (Some p) -> Some (aux_ps p)
  | Option None -> None
  | _ -> assert false

and aux_ps tree =
  let (p1, ps) = extract2 tree in
  let aux tree =
    let (_,p) = extract2 tree in
    aux_p p
  in
  let p1 = aux_p p1 in
  let ps =
    match ps with
    | List lst -> List.map aux lst
    | _ -> assert false
  in
  p1::ps

and aux_p (* map_parameter *) tree =
  match tree with
  | Case ("Param_with_defa_d9d11f1", tree) ->
    let (name,_,e) = extract3 tree in
    A.Default (aux_param_name name, aux_e e)
  | Case ("Param_with_defa_6e24c8f", tree) ->
    A.NoDefault (aux_param_name tree)
  | _ -> assert false

and aux_param_name (* map_parameter_name *) tree =
  match tree with
  | Case ("Dots", _) -> EllipsisId
  | Case ("Dot_dot_i", _) -> failwith "TODO: ..i argument"
  | Case ("Id", tree) -> ArgId (aux_tok tree)
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

and aux_float (* map_float_ *) tree =
  match tree with
  | Case ("Hex_lit", tok) -> aux_tok tok
  | Case ("Num_lit", tok) -> aux_tok tok
  | _ -> assert false

and aux_unary (* map_unary_operator *) tree =
  let aux tree =
    let _, _, a = extract3 tree in
    aux_e a
  in
  match tree with
  | Case ("QMARK_rep_nl_exp", tree) -> "?", aux tree
  | Case ("TILDE_rep_nl_exp", tree) -> "~", aux tree
  | Case ("BANG_rep_nl_exp", tree) -> "!", aux tree
  | Case ("PLUS_rep_nl_exp", tree) -> "+", aux tree
  | Case ("DASH_rep_nl_exp", tree) -> "-", aux tree
  | _ -> assert false

and aux_binary (* map_binary_operator *) tree =
  let aux tree =
    let a1, _, _, a2 = extract4 tree in
    aux_e a1, aux_e a2
  in
  match tree with
  | Case ("Exp_QMARK_rep_nl_exp", tree) -> "?", aux tree
  | Case ("Exp_TILDE_rep_nl_exp", tree) -> "~", aux tree
  | Case ("Exp_LTDASH_rep_nl_exp", tree) -> "<-", aux tree
  | Case ("Exp_LTLTDASH_rep_nl_exp", tree) -> "<<-", aux tree
  | Case ("Exp_COLONEQ_rep_nl_exp", tree) -> ":=", aux tree
  | Case ("Exp_DASHGT_rep_nl_exp", tree) -> "->", aux tree
  | Case ("Exp_DASHGTGT_rep_nl_exp", tree) -> "->>", aux tree
  | Case ("Exp_EQ_rep_nl_exp", tree) -> "=", aux tree
  | Case ("Exp_BAR_rep_nl_exp", tree) -> "|", aux tree
  | Case ("Exp_AMP_rep_nl_exp", tree) -> "&", aux tree
  | Case ("Exp_BARBAR_rep_nl_exp", tree) -> "||", aux tree
  | Case ("Exp_AMPAMP_rep_nl_exp", tree) -> "&&", aux tree
  | Case ("Exp_LT_rep_nl_exp", tree) -> "<", aux tree
  | Case ("Exp_LTEQ_rep_nl_exp", tree) -> "<=", aux tree
  | Case ("Exp_GT_rep_nl_exp", tree) -> ">", aux tree
  | Case ("Exp_GTEQ_rep_nl_exp", tree) -> ">=", aux tree
  | Case ("Exp_EQEQ_rep_nl_exp", tree) -> "==", aux tree
  | Case ("Exp_BANGEQ_rep_nl_exp", tree) -> "!=", aux tree
  | Case ("Exp_PLUS_rep_nl_exp", tree) -> "+", aux tree
  | Case ("Exp_DASH_rep_nl_exp", tree) -> "-", aux tree
  | Case ("Exp_STAR_rep_nl_exp", tree) -> "*", aux tree
  | Case ("Exp_SLASH_rep_nl_exp", tree) -> "/", aux tree
  | Case ("Exp_STARSTAR_rep_nl_exp", tree) -> "**", aux tree
  | Case ("Exp_HAT_rep_nl_exp", tree) -> "^", aux tree
  | Case ("Exp_pat_43ed24e_rep_nl_exp", _) ->
    (* pattern %[^%\\\n]*% *)
    let a1, tok, _, a2 = extract4 tree in
    aux_tok tok, (aux_e a1, aux_e a2)
  | Case ("Exp_BARGT_rep_nl_exp", tree) -> "|>", aux tree
  | Case ("Exp_COLON_rep_nl_exp", tree) -> ":", aux tree
  | _ -> assert false

and aux_fkind tree =
  match tree with
  | Case ("BSLASH", _) -> true
  | Case ("Func", _) -> false
  | _ -> assert false

and aux_tok tree  =
  match tree with
  | Token (_ (* loc *), str) -> str
  | _ -> assert false

let of_parser tree =
  Raw_tree.to_channel stdout tree ;
  aux_prog tree
