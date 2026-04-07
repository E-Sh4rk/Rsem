%{ (* Emacs, use -*- tuareg -*- to open this file. *)

%}

%token EOF
%token<string> ID SYM TY TYEQ
%start<Sigs.t> defs
%start<Sigs.sig_def> sig_def
%start<Sigs.alias_def> alias_def
%start<Sigs.elt> def

%%

(* === DEFS === *)

defs:
| defs=def* EOF { defs }

def:
| def=sig_def { let (id,ty) = def in Sig (id,ty) }
| def=alias_def { let (id,ty) = def in Alias (id, ty) }

sig_def:
| id=ID ty=TY { (id, Rstt_repl.IO.parse_type ty) }
| id=SYM ty=TY { (id, Rstt_repl.IO.parse_type ty) }

alias_def:
| id=ID ty=TYEQ { (id, Rstt_repl.IO.parse_type ty) }

