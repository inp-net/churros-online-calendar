{
  open Parser

  let string_buff = Buffer.create 256

  let char_for_backslash = function
    | 'n' -> '\010'
    | 'r' -> '\013'
    | 'b' -> '\008'
    | 't' -> '\009'
    | c   -> c
}

let backslash_escapes = ['\\' '\'' '"' 'n' 't' 'b' 'r' ' ']


rule token = parse
  | [' ' '\t' '\n' '\r'] { token lexbuf }

  | "null" { NULL }
  | ['0'-'9']+ as n { INT (int_of_string n) }
  | "true" { BOOL true }
  | "false" { BOOL false }
  | ['0'-'9']+("."['0'-'9']+)? as f { FLOAT (float_of_string f) }

  | "\"" { Buffer.clear string_buff; string lexbuf; STRING (Buffer.contents string_buff) }
  | "," { COMMA }
  | ":" { COLON }

  | "{" { LBRACE }
  | "}" { RBRACE }
  
  | "[" { LBRACKET }
  | "]" { RBRACKET }

  | eof { EOF }

and string = parse
  | '"' { () }
  | '\\' (backslash_escapes as c) { Buffer.add_char string_buff (char_for_backslash c); string lexbuf }
  | _ as c { Buffer.add_char string_buff c; string lexbuf }