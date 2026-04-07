%{ (* Emacs, use -*- tuareg -*- to open this file. *)

%}

%token VAL TYPE EOF
%token<string> ID SYM TY TYEQ
%start<Sigs.t> defs
%start<Sigs.sig_def> sig_def

%%

(* === DEFS === *)

defs:
| defs=def* EOF { defs }

def:
| VAL id=ID ty=TY { Sig (id, Rstt_repl.IO.parse_type ty) }
| VAL id=SYM ty=TY { Sig (id, Rstt_repl.IO.parse_type ty) }
| TYPE name=ID ty=TYEQ { Alias (name, Rstt_repl.IO.parse_type ty) }

sig_def:
| id=ID ty=TY { (id, Rstt_repl.IO.parse_type ty) }
