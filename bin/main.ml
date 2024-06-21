open Lwt.Infix

let events = 10

let graphql = Printf.sprintf {|
  {
    events(last: %i) {
      nodes {
        uid
        title
        description
        startsAt
        endsAt
        location
        group {
          name
        }
      }
    }
  }
|} events

let req_body = Printf.sprintf {|
  {
    "query":"%s",
    "extensions":{}
  }
|} (String.escaped graphql)

let body =
  Cohttp_lwt_unix.Client.post
  ~headers:(Cohttp.Header.init_with "Content-Type" "application/json")
  ~body:(Cohttp_lwt.Body.of_string req_body) (Uri.of_string "https://churros.inpt.fr/graphql")
  >>= fun (_, body) -> body |> Cohttp_lwt.Body.to_string

let () =
  let body = Lwt_main.run body in
  let parsed = Option.get (Lexer.from_string Parser.file body) in
  let file = open_out "churros_calendar.ics" in
  Printf.fprintf file "%s" (Ics.print_ics (Calendar.ics_of_json parsed));
  close_out file