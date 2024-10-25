open Lwt.Infix

let events = 20
let timeout = 20
let port = 8080
let churros_graphql_url = "https://churros.inpt.fr/graphql"

let graphql =
  Printf.sprintf
    {|
  {
    events(last: %i) {
      nodes {
        id
        title
        description
        startsAt
        endsAt
        updatedAt
        location
        organizer {
          name
        }
      }
    }
  }
|}
    events

(** obtient le corps de la requête post pour exécuter la requête graphql demandée
    @param graphql la string contenant la requête graphql formattée
 *)
let req_body graphql =
  Printf.sprintf
    {|
      {
        "query":"%s",
        "extensions":{}
      }
    |}
    (String.escaped graphql)

let _ =
  Persistence.ensure_tables_exist () >>= function
  | Ok () -> Lwt_io.eprintl "database connection ok"
  | Error `Connection_database_error ->
      Lwt_io.eprintl "cannot connect database, please verify your configuration"
      >|= fun () -> exit 1
  | Error `Internal_database_error ->
      Lwt_io.eprintl
        "internal database error, if the error persist, try contact the \
         developper"
      >|= fun () -> exit 1

(** Fait une requête à l'api churros sur /me pour obtenir l'uid de l'user
    à qui appartient le token (permet également de s'assurer que le token est valide)
    @param churros_token le token dont on cherche l'user
    @return Some churros_uid ou None si le token est invalide
 *)
let request_churros_uid churros_token =
  let headers =
    let h = Cohttp.Header.init_with "Content-Type" "application/json" in
    Cohttp.Header.add h "Authorization"
      (Printf.sprintf "Bearer %s" churros_token)
  and body =
    Cohttp_lwt.Body.of_string
      (req_body {|
      {
        me {
          uid
        }
      }
  |})
  in
  let%lwt _, churros_response_body =
    Cohttp_lwt_unix.Client.post ~headers ~body
      (Uri.of_string churros_graphql_url)
  in
  Cohttp_lwt.Body.to_string churros_response_body >>= fun s ->
  match Option.get (Lexer.from_string Parser.file s) with
  | Json.J_Object
      [
        {
          key = "data";
          value =
            J_Object
              [
                {
                  key = "me";
                  value =
                    J_Object [ { key = "uid"; value = J_String churros_uid } ];
                };
              ];
        };
      ] ->
      Lwt.return (Some churros_uid)
  | _ -> Lwt.return None

(** Fait une requête à l'api churros sur /me pour vérifier que le token est
    toujours valide
    @param token le token à vérifier
    @return true si le token est valide, false otherwise
 *)
let verify_churros_token churros_token =
  request_churros_uid churros_token >>= function
  | Some _ -> Lwt.return true
  | None -> Lwt.return false

let json_txt_to_ics s =
  Option.get (Lexer.from_string Parser.file s)
  |> Calendar.ics_of_json |> Ics.print_ics

(* Initialize the Logs library *)
let setup_logging () =
  (* Create a reporter that outputs to stdout *)
  let reporter = Logs_fmt.reporter () in
  (* Set the Logs reporter to the one we created *)
  Logs.set_reporter reporter;
  (* Set the log level to Debug *)
  Logs.set_level (Some Logs.Warning)

let main () =
  (* Call setup_logging to initialize logging *)
  setup_logging ();
  (* Example of logging a debug message *)
  Logs_lwt.debug (fun m -> m "This is a debug message") >>= fun () ->
  (* Your main program logic here *)
  Lwt.return ()

(** Fait une requête à l'api churros et transforme le résultat en ICS
    @param token Some <churros_token> pour obtenir le calendrier d'un user ou
    None pour obtenir le calendrier des événements publics
 *)
let get_calendar_content token =
  let headers =
    let h = Cohttp.Header.init_with "Content-Type" "application/json" in
    match token with
    | None -> h
    | Some churros_token ->
        Cohttp.Header.add h "Authorization"
          (Printf.sprintf "Bearer %s" churros_token)
  in
  let%lwt _, churros_response_body =
    Cohttp_lwt_unix.Client.post ~headers
      ~body:(Cohttp_lwt.Body.of_string (req_body graphql))
      (Uri.of_string churros_graphql_url)
  in
  Cohttp_lwt.Body.to_string churros_response_body >>= fun s ->
  Lwt.return (json_txt_to_ics s)

let server =
  let callback _ req req_body =
    match Cohttp_lwt_unix.Request.meth req with
    | `GET -> (
        let request_path = Cohttp_lwt_unix.Request.uri req |> Uri.path in
        match String.split_on_char '/' request_path with
        | [ ""; "calendars"; "public" ] ->
            let%lwt body = get_calendar_content None in
            Cohttp_lwt_unix.Server.respond_string
              ~headers:(Cohttp.Header.init_with "Content-Type" "text/calendar")
              ~status:`OK ~body ()
        | "" :: "calendars" :: calendar_uid :: _ -> (
            (* This match every url that begin with /calendars/<calendar_uid> *)
            let%lwt token =
              Persistence.get_token_from_calendar_uid calendar_uid
            in
            match token with
            | Ok token ->
                (* start the first request in parallel for faster result *)
                let body = get_calendar_content (Some token) in
                let%lwt test_token = verify_churros_token token in
                if test_token then
                  body >>= fun body ->
                  Cohttp_lwt_unix.Server.respond_string
                    ~headers:
                      (Cohttp.Header.init_with "Content-Type" "text/calendar")
                    ~status:`OK ~body ()
                else
                  Cohttp_lwt_unix.Server.respond_error ~status:`Unauthorized
                    ~body:
                      "Failed to authenticate to churros (token invalid), you \
                       must register a new token"
                    ()
            | Error `Calendar_does_not_exist ->
                Cohttp_lwt_unix.Server.respond_error ~status:`Not_found
                  ~body:"Not found" ()
            | Error `No_saved_token_for_user ->
                Cohttp_lwt_unix.Server.respond_error ~status:`Unauthorized
                  ~body:
                    "You didn't gave us the permission to connect to churros \
                     yet, you must register a churros token first"
                  ()
            | Error `Internal_database_error | Error `Connection_database_error
              ->
                print_endline "Error: failed to query churros token";
                Cohttp_lwt_unix.Server.respond_error
                  ~status:`Internal_server_error ~body:"Internal server error"
                  ())
        | _ ->
            Cohttp_lwt_unix.Server.respond_error ~status:`Not_found
              ~body:"Not found" ())
    | `POST -> (
        let headers =
          (* The CORS header is needed to make the api publicly accessible *)
          Cohttp.Header.init_with "Access-Control-Allow-Origin" "*"
        in
        let request_path = Cohttp_lwt_unix.Request.uri req |> Uri.path in
        match String.split_on_char '/' request_path with
        | [ ""; "register" ] -> (
            let%lwt token = Cohttp_lwt.Body.to_string req_body in
            request_churros_uid token >>= function
            | Some churros_uid -> (
                Persistence.register_user_token churros_uid token >>= function
                | Ok () | Error `Token_already_exist -> (
                    Persistence.get_user_calendar churros_uid >>= function
                    | Ok body ->
                        Cohttp_lwt_unix.Server.respond_string ~headers
                          ~status:`OK ~body ()
                    | Error _ ->
                        print_endline "Error: failed to query calendar id";
                        Cohttp_lwt_unix.Server.respond_error ~headers
                          ~status:`Internal_server_error
                          ~body:"Internal server error" ())
                | Error `Internal_database_error
                | Error `Connection_database_error ->
                    print_endline "Error: failed to query churros token";
                    Cohttp_lwt_unix.Server.respond_error ~headers
                      ~status:`Internal_server_error
                      ~body:"Internal server error" ())
            | None ->
                Cohttp_lwt_unix.Server.respond_error ~status:`Unauthorized
                  ~headers ~body:"Invalid churros token" ())
        | _ ->
            Cohttp_lwt_unix.Server.respond_error ~status:`Not_found ~headers
              ~body:"Not found" ())
    | meth ->
        Cohttp_lwt_unix.Server.respond_error ~status:`Method_not_allowed
          ~body:
            (Printf.sprintf "Method %s is not suported"
               (Cohttp.Code.string_of_method meth))
          ()
  in
  main () >>= fun () ->
  Cohttp_lwt_unix.Server.create ~timeout
    ~mode:(`TCP (`Port port))
    (Cohttp_lwt_unix.Server.make ~callback ())

let () = ignore (Lwt_main.run server)
