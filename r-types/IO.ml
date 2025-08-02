open Common
open Lexing

exception LexicalError of Position.t * string
exception SyntaxError of Position.t * string

let pos_of_lexbuf lexbuf =
  let pos = lexbuf.lex_curr_p in
  Position.lex_join pos pos

let parse_with_errors parser buf =
  try parser Lexer.token buf with
  | Lexer.LexerError msg ->
    raise (LexicalError (pos_of_lexbuf buf, msg))
  | Parser.Error ->
    raise (SyntaxError (pos_of_lexbuf buf, "syntax error"))

let parse_type_string str =
  let buf = from_string str in
  buf.lex_curr_p <- { buf.lex_curr_p with  pos_fname = "_" };
  parse_with_errors Parser.unique_typ buf

let parse_type_defs_file source_filename =
  let cin = open_in source_filename in
  let buf = from_channel cin in
  buf.lex_curr_p <- { buf.lex_curr_p with  pos_fname = source_filename };
  parse_with_errors Parser.defs buf
