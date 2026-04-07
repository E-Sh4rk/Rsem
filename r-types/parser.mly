%{ (* Emacs, use -*- tuareg -*- to open this file. *)

%}

%token<string> ID SYM TY TYEQ
%start<Sigs.sig_def> sig_def
%start<Sigs.alias_def> alias_def
%start<Sigs.t> def

%%

def:
| def=sig_def { let (id,ty) = def in Sigs.Sig (id,ty) }
| def=alias_def { let (id,ty) = def in Sigs.Alias (id, ty) }

sig_def:
| id=ID ty=TY { (id, Rstt_repl.IO.parse_type ty) }
| id=SYM ty=TY { (id, Rstt_repl.IO.parse_type ty) }

alias_def:
| id=ID ty=TYEQ { (id, Rstt_repl.IO.parse_type ty) }

