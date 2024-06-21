open Lwt.Infix

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

let req_body = Printf.sprintf {|
  {
    "query":"%s",
    "extensions":{}
  }
|} (String.escaped graphql)

let body =
  Cohttp_lwt_unix.Client.post ~headers:(Cohttp.Header.init_with "Content-Type" "application/json")
  ~body:(Cohttp_lwt.Body.of_string req_body) (Uri.of_string "https://churros.inpt.fr/graphql")
  >>= fun (resp, body) ->
  let code = resp |> Cohttp_lwt_unix.Response.status |> Cohttp.Code.code_of_status in
  Printf.printf "Response code: %d\n" code;
  Printf.printf "Headers: %s\n" (resp |> Cohttp_lwt_unix.Response.headers |> Cohttp.Header.to_string);
  body |> Cohttp_lwt.Body.to_string >|= fun body ->
  Printf.printf "Body of length: %d\n" (String.length body);
  body

let () =
  let body = Lwt_main.run body in
  print_endline ("Received body\n" ^ body)


let () =
  let parsed = Option.get (Lexer.from_string Parser.file "") in
  print_endline (Syntax.show_t_json parsed)
