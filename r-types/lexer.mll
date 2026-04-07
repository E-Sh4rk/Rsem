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

let id = ['a'-'z''_''A'-'Z']['a'-'z''A'-'Z''0'-'9''_''\'''?''!''+''-''['']''$''@''<''>']*
let sym = ['+''-''['']''$''@''<''>']+

rule token = parse
| newline { enter_newline lexbuf |> token }
| blank   { token lexbuf }
| "val" { VAL }
| "type"  { TYPE }
| "(*"    { comment 0 lexbuf }
| ':'     { TY (read_ty (Buffer.create 17) lexbuf) }
| '='     { TYEQ (read_ty (Buffer.create 17) lexbuf) }
| id as s { ID s }
| '(' (sym as s) ')' { SYM s }
| eof     { EOF }
| _ { raise (LexerError ("Unexpected char: " ^ Lexing.lexeme lexbuf)) }

and comment depth = parse
| newline { enter_newline lexbuf |> comment depth }
| "*)" {
  if depth = 0 then token lexbuf else comment (depth - 1) lexbuf
}
| "(*" {
  comment (depth + 1) lexbuf
}
| eof { EOF }
| _ {
  comment depth lexbuf
}

and read_ty buf = parse
| escaped_newline {
  enter_newline lexbuf |> read_ty buf }
| newline { Buffer.contents buf }
| eof { Buffer.contents buf }
| _
  { Buffer.add_string buf (Lexing.lexeme lexbuf);
    read_ty buf lexbuf
  }
