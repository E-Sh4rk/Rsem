%{ (* Emacs, use -*- tuareg -*- to open this file. *)

  open Types.TyExpr
  open RBuilder.Ext
  open Defs

  let builtin_type_or_custom str =
    match str with
    | "empty" -> TBase TEmpty
    | "any" -> TBase TAny
    | "tuple" -> TBase TTupleAny
    | "arrow" -> TBase TArrowAny
    | "record" -> TBase TRecordAny
    | "enum" -> TBase TEnumAny
    | "tag" -> TBase TTagAny
    | "int" -> TBase (TInt (None, None))
    | "char" -> TBase TChar
    | "float" -> TBase TFloat
    | "string" -> TBase TString
    | "list" -> TBase TList
    | "bool" -> TBase TBool
    | str ->
      let regexp = Str.regexp {|^tuple\([0-9]*\)$|} in
      if Str.string_match regexp str 0 then
        let nb = Str.matched_group 1 str in
        TBase (TTupleN (int_of_string nb))
      else
        TCustom str

  let builtin_enum_or_custom str =
    match str with
    | "NA" -> TExt (Na)
    | "INT" -> TExt (Vec (false, INT))
    | "LGL" -> TExt (Vec (false, LGL))
    | "DBL" -> TExt (Vec (false, DBL))
    | "CLX" -> TExt (Vec (false, CLX))
    | "CHR" -> TExt (Vec (false, CHR))
    | "RAW" -> TExt (Vec (false, RAW))
    | "INT?" -> TExt (Vec (true, INT))
    | "LGL?" -> TExt (Vec (true, LGL))
    | "DBL?" -> TExt (Vec (true, DBL))
    | "CLX?" -> TExt (Vec (true, CLX))
    | "CHR?" -> TExt (Vec (true, CHR))
    | "RAW?" -> TExt (Vec (true, RAW))
    | str -> TEnum str

  type field_name = Ellipis | Named of string | Positional

  let record_fields fields =
    fields |> List.mapi (fun i (n,t,b) ->
      let n = match n with
      | Positional -> Args.id_of_pos i
      | Named n -> Args.id_of_name n
      | Ellipis -> Args.id_of_ellipsis
      in
      n,t,b
    )

%}

%token VAL UNARY BINARY TYPE EOF
%token LPAREN RPAREN EQUAL COMMA CONS COLON COLON_OPT
%token INTERROGATION_MARK EXCLAMATION_MARK
%token ARROW AND OR NEG DIFF
%token TIMES PLUS MINUS
%token LBRACE RBRACE DOUBLEPOINT TRIPLEPOINT
%token AND_KW OR_KW
%token WHERE
%token LBRACKET RBRACKET SEMICOLON
%token<string> ID CID PCID
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
| VAL id=op_id COLON ty=typ { Sig (id, ty) }
| VAL UNARY id=op_id COLON ty=typ { Sig (id^"__1", ty) }
| VAL BINARY id=op_id COLON ty=typ { Sig (id^"__2", ty) }
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
| s=CID { builtin_enum_or_custom s }
| s=PCID t=typ RPAREN { TTag (s, t) }
| s=PCID RPAREN { TTag (s, TBase TUnit) }
| s=TVAR { TVar s }
| s=TVAR_WEAK { TVarWeak s }
| LPAREN RPAREN { TBase TUnit }
| LPAREN t=typ RPAREN { t }
| LBRACE fs=separated_list(SEMICOLON, typ_field) o=optional_open RBRACE
{ TRecord (o, record_fields fs) }
| LBRACKET re=typ_re RBRACKET { TSList re }

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
