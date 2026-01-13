%{ (* Emacs, use -*- tuareg -*- to open this file. *)

%}

%token VAL UNARY BINARY TYPE EQUAL EOF
%token<string> ID SYM TY
%start<Defs.t> defs

%%

(* === DEFS === *)

defs:
| defs=def* EOF { defs }

def:
| VAL id=ID ty=TY { Sig (id, Rstt_repl.IO.parse_type ty) }
| VAL UNARY id=SYM ty=TY { Sig (id^"__1", Rstt_repl.IO.parse_type ty) }
| VAL BINARY id=SYM ty=TY { Sig (id^"__2", Rstt_repl.IO.parse_type ty) }
| TYPE name=ID EQUAL ty=TY { Alias (name, Rstt_repl.IO.parse_type ty) }
