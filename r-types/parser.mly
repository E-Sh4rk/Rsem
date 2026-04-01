%{ (* Emacs, use -*- tuareg -*- to open this file. *)

%}

%token VAL UNARY BINARY TYPE EOF
%token<string> ID SYM TY TYEQ
%start<Sigs.t> defs
%start<Sigs.sig_def> sig_def

%%

(* === DEFS === *)

defs:
| defs=def* EOF { defs }

def:
| VAL id=ID ty=TY { Sig (id, Rstt_repl.IO.parse_type ty) }
| VAL UNARY id=SYM ty=TY { Sig (id^"__1", Rstt_repl.IO.parse_type ty) }
| VAL BINARY id=SYM ty=TY { Sig (id^"__2", Rstt_repl.IO.parse_type ty) }
| TYPE name=ID ty=TYEQ { Alias (name, Rstt_repl.IO.parse_type ty) }

sig_def:
| id=ID ty=TY { (id, Rstt_repl.IO.parse_type ty) }
