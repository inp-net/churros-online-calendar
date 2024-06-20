open Parser
open Sedlexing.Utf8

exception Lexer_unknown_token of string

let newline = [%sedlex.regexp? ('\r' | '\n' | "\r\n") ]
let whitespace = [%sedlex.regexp? Plus (' ' | '\t' | newline)]
let number = [%sedlex.regexp? Plus '0'..'9']
let float = [%sedlex.regexp? number, Opt ('.', number)]
let string = [%sedlex.regexp? '"', Star (Compl '"'), '"']
let escaped_string = [%sedlex.regexp? '"', Star (Compl ('"' | '\\') | '\\', any), '"']

let rec tokenizer lexbuf =
  match%sedlex lexbuf with
  | whitespace -> tokenizer lexbuf
  |"null" -> NULL
  | number -> INT (int_of_string (lexeme lexbuf))
  | "true" -> BOOL true
  | "false" -> BOOL false
  | float -> FLOAT (float_of_string (lexeme lexbuf))
  | escaped_string -> STRING (String.sub (lexeme lexbuf) 1 ((String.length (lexeme lexbuf)) - 2))
  | "," -> COMMA
  | ":" -> COLON
  | "{" -> LBRACE
  | "}" -> RBRACE
  | "[" -> LBRACKET
  | "]" -> RBRACKET
  | "//" -> single_comment lexbuf
  | "/*" -> multi_comment lexbuf
  | eof -> EOF
  | _ -> raise (Lexer_unknown_token (lexeme lexbuf))
and single_comment lexbuf =
  print_string (lexeme lexbuf);
  match%sedlex lexbuf with
  | newline -> tokenizer lexbuf
  | any -> single_comment lexbuf
  | eof -> EOF
  | _ -> raise (Lexer_unknown_token (lexeme lexbuf))
and multi_comment lexbuf =
  print_string (lexeme lexbuf);
  match%sedlex lexbuf with
  | "*/" -> tokenizer lexbuf
  | any -> multi_comment lexbuf
  | eof -> EOF
  | _ -> raise (Lexer_unknown_token (lexeme lexbuf))

let provider buf () =
  let token = tokenizer buf in
  let start, stop = Sedlexing.lexing_positions buf in
  (token, start, stop)

let from_string parser string =
  let buf = from_string string in
  let provider = provider buf in
  MenhirLib.Convert.Simplified.traditional2revised parser provider