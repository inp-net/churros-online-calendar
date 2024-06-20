let graphql = {|
  {
    events(last: 4) {
      nodes {
        uid
        startsAt
        endsAt
        location
        group {
          name
        }
      }
    }
  }
|}

let request = Printf.sprintf {|
  POST /graphql HTTP/2
  Host: churros.inpt.fr
  User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:126.0) Gecko/20100101 Firefox/126.0
  Accept: application/graphql-response+json, application/json, multipart/mixed
  Accept-Language: fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3
  Accept-Encoding: gzip, deflate, br, zstd
  Content-Type: application/json
  Content-Length: 173
  Origin: https://churros.inpt.fr
  Sec-Fetch-Dest: empty
  Sec-Fetch-Mode: cors
  Sec-Fetch-Site: same-origin
  Connection: keep-alive
  Priority: u=1

  {
    "query":"%s",
    "extensions":{}
  }
|} graphql

let _ =
  let response = Http.http_request request "churros.inpt.fr" 443 in
  print_endline response;
  let parsed = Option.get (Lexer.from_string Parser.file response) in
  print_endline (Syntax.show_t_json parsed)
