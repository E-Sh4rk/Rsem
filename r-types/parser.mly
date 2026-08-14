%{ (* Emacs, use -*- tuareg -*- to open this file. *)

%}

%token<string> ID SYM TY TYEQ
%token NEW COLONCOLON
%start<Sigs.sig_def> sig_def
%start<Sigs.alias_def> alias_def
%start<Sigs.t> def

%%

def:
| def=sig_def { let (id,ty) = def in Sigs.Sig (id,ty) }
| def=local_sig_def { let (f,id,ty) = def in Sigs.LocalSig (f,id,ty) }
| def=alias_def { let (id,ty) = def in Sigs.Alias (id, ty) }
| NEW id=name { Sigs.NewClass id }

(* [new] is a keyword only when it introduces a class-overload declaration:
   it remains usable as a regular identifier elsewhere. *)
%inline name:
| id=ID { id }
| id=SYM { id }
| NEW { "new" }

sig_def:
| id=name ty=TY { (id, Sigs.parse_annot ty) }

(* [f::x : t] annotates the variable [x] local to the top-level function [f]. *)
local_sig_def:
| f=name COLONCOLON id=name ty=TY { (f, id, Sigs.parse_annot ty) }

alias_def:
| id=ID ty=TYEQ { (id, Rstt_repl.IO.parse_type ty) }
