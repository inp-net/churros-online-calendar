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


(*
let () =
  let body = Lwt_main.run body in
  let parsed = Option.get (Lexer.from_string Parser.file body) in
  let file = open_out "churros_calendar.ics" in
  Printf.fprintf file "%s" (Ics.print_ics (Calendar.ics_of_json parsed));
  close_out file
*)


let get_ics_string () =
  Lwt_main.run body |> fun s -> Option.get (Lexer.from_string Parser.file s)
  |> Calendar.ics_of_json |> Ics.print_ics

let ics_string = get_ics_string ()

let server =
  let callback _ req _ = match Cohttp_lwt_unix.Request.meth req with
  | `GET -> (* get_ics_string () |> fun body -> Cohttp_lwt_unix.Server.respond_string ~status:`OK ~body () *)
    (*
    let uri = req |> Cohttp_lwt_unix.Request.uri |> Uri.to_string in
    let meth = req |> Cohttp_lwt_unix.Request.meth |> Cohttp.Code.string_of_method in
    let body = Printf.sprintf "Uri: %s\nMethod: %s\nBody: %s" uri meth "coucou" in
    *)
    Cohttp_lwt_unix.Server.respond_string ~status:`OK ~body:ics_string ()
  | meth ->
    Cohttp_lwt_unix.Server.respond_error ~status:`Method_not_allowed
    ~body:(Printf.sprintf "Method %s is not suported" (Cohttp.Code.string_of_method meth)) ()
  in
  Cohttp_lwt_unix.Server.create ~mode:(`TCP (`Port 8080)) (Cohttp_lwt_unix.Server.make ~callback ())

let () = ignore (Lwt_main.run server)
