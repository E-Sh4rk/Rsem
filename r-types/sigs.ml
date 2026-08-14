open Rstt

(* A type annotation, as written in a declaration. It is parsed as a function
   signature ([AFun]) whenever possible, and as a regular type ([ATy])
   otherwise: this is what determines whether the annotated definition is a
   function or not. Contrarily to a regular type, a function signature may
   contain label variables. *)
type annot =
| ATy of (string,string,string) Builder.t
| AFun of (string,string,string) FunSig.t

type sig_def = string * annot
(* Annotation of a variable that is local to a top-level function: the name of
   the enclosing top-level function, the name of the variable, and its type. *)
type local_sig_def = string * string * annot
type alias_def = string * (string,string,string) Builder.t
(* Declaration of a new class-overload (S3 dispatch): the name of the method,
   for instance [print.myclass]. *)
type class_def = string

type t =
| Sig of sig_def
| LocalSig of local_sig_def
| Alias of alias_def
| NewClass of class_def

(* Offset the parsing of [str] reached before failing. *)
let error_offset e =
  match e with
  | Rstt_repl.IO.LexicalError (pos, _) | Rstt_repl.IO.SyntaxError (pos, _) ->
    (Rstt_repl.Position.end_of_position pos).Lexing.pos_cnum
  | _ -> min_int

let parse_annot str =
  match Rstt_repl.IO.parse_funsig str with
  | fsig -> AFun fsig
  | exception ((Rstt_repl.IO.LexicalError _ | Rstt_repl.IO.SyntaxError _) as e1) ->
    (* [str] may simply not be a function signature. *)
    begin match Rstt_repl.IO.parse_type str with
    | ty -> ATy ty
    | exception ((Rstt_repl.IO.LexicalError _ | Rstt_repl.IO.SyntaxError _) as e2) ->
      (* Both parsers failed: report the one that went the furthest, as it is
         the most likely to point at the actual mistake. *)
      raise (if error_offset e2 < error_offset e1 then e1 else e2)
    end
