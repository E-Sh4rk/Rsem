%{ (* Emacs, use -*- tuareg -*- to open this file. *)

  open Types.TyExpr
  open RBuilder.Ext
  open Defs
  open Sigs

  let builtin_type_or_custom str =
    match str with
    | "int" -> TExt (Prim INT)
    | "lgl" -> TExt (Prim LGL)
    | "dbl" -> TExt (Prim DBL)
    | "clx" -> TExt (Prim CLX)
    | "chr" -> TExt (Prim CHR)
    | "raw" -> TExt (Prim RAW)
    | "prim" -> TExt (AnyPrim)
    | "empty" -> TBase TEmpty
    | "any" -> TBase TAny
    (* Legacy *)
    | "tuple" -> TBase TTupleAny
    | "arrow" -> TBase TArrowAny
    | "record" -> TBase TRecordAny
    | "enum" -> TBase TEnumAny
    | "tag" -> TBase TTagAny
    | str ->
      let regexp = Str.regexp {|^tuple\([0-9]*\)$|} in
      if Str.string_match regexp str 0 then
        let nb = Str.matched_group 1 str in
        TBase (TTupleN (int_of_string nb))
      else
        TCustom str

  module StrMap = Map.Make(String)
  let fnames = ref StrMap.empty
  let fnum = ref 0
  let fdone = ref false
  let register_field str i =
    if not !fdone then fnames := StrMap.add str i !fnames
  let incr_num () = if not !fdone then fnum := !fnum + 1

  type field_name = Ellipis | Named of string | Positional

  let record_fields fields =
    let res = fields |> List.mapi (fun i (n,t,b) ->
      let n = match n with
      | Positional ->
        begin match t with
        | TExt (Ell _) -> Ellipsis.id
        | _ -> incr_num () ; Args.id i
        end
      | Named name ->
        incr_num () ; register_field name i ; Args.id i
      | Ellipis -> Ellipsis.id
      in
      n,t,b
    )
    in
    fdone := true ; res

  let registered_funinfo () =
    let res = {
      FunInfo.names = !fnames ;
      FunInfo.num = !fnum
    } in
    fnum := 0 ; fnames := StrMap.empty ; fdone := false ; res

%}

%token VAL UNARY BINARY TYPE EOF
%token LPAREN RPAREN EQUAL COMMA CONS COLON COLON_OPT
%token INTERROGATION_MARK EXCLAMATION_MARK
%token VEC_NNA VEC_NA VEC
%token ARROW AND OR NEG DIFF
%token TIMES PLUS MINUS
%token LBRACE RBRACE LT GT DOUBLEPOINT TRIPLEPOINT
%token AND_KW OR_KW
%token WHERE
%token LBRACKET RBRACKET SEMICOLON
%token<string> ID
%token<string> TVAR TVAR_WEAK
%token<float> LFLOAT
%token<Z.t> LINT
%token<bool> LBOOL
%token<char> LCHAR
%token<string> LSTRING

%start<RBuilder.type_expr> unique_typ
%start<RBuilder.type_defs> defs

%right ARROW
%left OR
%left AND
%left DIFF
%right CONS
%nonassoc NEG

%%

(* === DEFS === *)

defs:
| defs=def* EOF { defs }

def:
| VAL id=op_id COLON ty=typ { Sig (id, ty, registered_funinfo ()) }
| VAL UNARY id=op_id COLON ty=typ { Sig (id^"__1", ty, registered_funinfo ()) }
| VAL BINARY id=op_id COLON ty=typ { Sig (id^"__2", ty, registered_funinfo ()) }
| TYPE defs=separated_nonempty_list(AND_KW, param_type_def) { Aliases defs }

op_id:
| id=ID { id }
| LPAREN id=prefix RPAREN { id }

prefix:
| INTERROGATION_MARK { "?" }
| EXCLAMATION_MARK { "!" }
| NEG { "~" }
| PLUS { "+" }
| MINUS { "-" }
| LT { "<" }
| GT { ">" }

(* === TYPES === *)

unique_typ : t=typ EOF { t }

typ:
  t=typ_norec { t }
| t=typ_norec WHERE ts=separated_nonempty_list(AND_KW, param_type_def)
  { TWhere (t, ts) }

%inline param_type_def:
| name=ID EQUAL t=typ_norec { (name, [], t) }
| name=ID LPAREN params=separated_list(COMMA, TVAR) RPAREN EQUAL t=typ_norec { (name, params, t) }

typ_norec:
  t=simple_typ { t }
| hd=simple_typ COMMA tl=separated_nonempty_list(COMMA, simple_typ) { TTuple (hd::tl) }

simple_typ:
  t=atomic_typ { t }
| s=ID LPAREN ts=separated_list(COMMA, simple_typ) RPAREN { TApp(s, ts) }
| lhs=simple_typ ARROW rhs=simple_typ { TArrow (lhs, rhs) }
| lhs=simple_typ CONS rhs=simple_typ  { TCons (lhs, rhs) }
| NEG t=simple_typ { TNeg t }
| lhs=simple_typ OR rhs=simple_typ  { TCup (lhs, rhs) }
| lhs=simple_typ AND rhs=simple_typ { TCap (lhs, rhs) }
| lhs=simple_typ DIFF rhs=simple_typ  { TDiff (lhs, rhs) }

atomic_typ:
  x=type_constant { TBase x }
| s=ID { builtin_type_or_custom s }
| s=TVAR { TVar (KNoInfer, s) }
| s=TVAR_WEAK { TVar (KInfer, s) }
| v=vec LBRACKET i=typ RBRACKET LPAREN p=typ RPAREN { TExt (Vec (p,v,i)) }
| TRIPLEPOINT LPAREN t=typ RPAREN { TExt (Ell t) }
| LPAREN RPAREN { TBase TUnit }
| LPAREN t=typ RPAREN { t }
| LBRACE fs=separated_list(SEMICOLON, typ_field) o=optional_open RBRACE
{ TRecord (o, record_fields fs) }
| LBRACKET re=typ_re RBRACKET { TSList re }

%inline vec:
  VEC_NNA { TBase TEmpty }
| VEC_NA { TBase TAny }
| VEC { TBase TAny }
| VEC LT t=typ GT { t }

%inline optional_open:
  { false }
| DOUBLEPOINT { true }

%inline typ_field:
  id=ID COLON t=simple_typ { (Named id, t, false) }
| id=ID COLON_OPT t=simple_typ { (Named id, t, true) }
| TRIPLEPOINT COLON t=simple_typ { (Ellipis, t, false) }
| TRIPLEPOINT COLON_OPT t=simple_typ { (Ellipis, t, true) }
| t=simple_typ { (Positional, t, false) }
| INTERROGATION_MARK t=simple_typ { (Positional, t, true) }

%inline type_constant:
| i=tint { TInt (Some i, Some i) }
| LPAREN i1=tint? DOUBLEPOINT i2=tint? RPAREN { TInt (i1,i2) }
| c=LCHAR { TCharInt (c,c) }
| LPAREN c1=LCHAR MINUS c2=LCHAR RPAREN { TCharInt (c1,c2) }
| b=LBOOL { if b then TTrue else TFalse }
| str=LSTRING { TSString str }

tint:
  i=LINT { i }
// | PLUS i=LINT { i } // conflict with with regexp
| MINUS i=LINT { Z.neg i }

(* ===== REGEX ===== *)

typ_re:
| { Epsilon }
| re=nonempty_re { re }

nonempty_re:
| res=separated_nonempty_list(OR, simple_re) { Union res }

simple_re:
| res=nonempty_list(atomic_re) { Concat res }

atomic_re:
  t=atomic_typ { Symbol t }
| EXCLAMATION_MARK LPAREN re=nonempty_re RPAREN { re }
| re=atomic_re TIMES { Star re }
| re=atomic_re PLUS { Plus re }
| re=atomic_re INTERROGATION_MARK { Option re }
