{
  open Parser

  exception LexerError of string

  let enter_newline lexbuf =
    Lexing.new_line lexbuf;
    lexbuf
}

let backslash_escapes = ['\\' '\'' '"' 'n' 't' 'b' 'r' ' ']

let newline = ('\010' | '\013' | "\013\010")
let escaped_newline = '\\' newline

let blank   = [' ' '\009' '\012']

(* R identifiers may start with a dot, and the ones that do are the ones a
   prelude most needs: [.Platform], [.Machine], the [.onLoad] hooks. Nothing
   else in this lexer starts with a dot -- numbers only ever occur inside a
   type, which [read_ty] hands over as a raw string -- so admitting it here is
   unambiguous. *)
let id = ['a'-'z''_''A'-'Z''.']['a'-'z''A'-'Z''0'-'9''_''\'''?''!''+''-''['']''$''@''<''>''.']*
let sym = ['+''-''['']''$''@''<''>'':''=''*''%''/''|''&''!''^''~']+

rule token = parse
| newline { enter_newline lexbuf |> token }
| blank   { token lexbuf }
| "::"    { COLONCOLON }
| ':'     { TY (read_ty (Buffer.create 17) lexbuf) }
| '='     { TYEQ (read_ty (Buffer.create 17) lexbuf) }
| "new"   { NEW }
| id as s { ID s }
| '(' (sym as s) ')' { SYM s }
| _ { raise (LexerError ("Unexpected char: " ^ Lexing.lexeme lexbuf)) }

and read_ty buf = parse
| escaped_newline {
  enter_newline lexbuf |> read_ty buf }
| newline { Buffer.contents buf }
| eof { Buffer.contents buf }
| _
  { Buffer.add_string buf (Lexing.lexeme lexbuf);
    read_ty buf lexbuf
  }
