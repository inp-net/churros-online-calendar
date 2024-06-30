open Lwt.Infix

let ( >>=? ) m f =
  m >>= function Ok x -> f x | Error err -> Lwt.return (Error err)

(*
let report_error = function
  | Ok () -> Lwt.return_unit
 | Error err ->
     Lwt_io.eprintl (Caqti_error.show err) >|= fun () -> exit 69
     *)

(** Run a fonction at most (number_retries + 1) times until there is not an SQL unique_constraint error 
    if there is another SQL error, the function stop and the error is returned.

    @param f the function that perform a sql query that can have collisions with existing values in the database,
        it takes the number of left retries at unique parameter
    @param number_tries the maximum number of times the f function can be called
 *)
let try_while_unique_violation f number_tries =
  let rec aux response = function
    | 0 -> Lwt.return response
    | retries_lefts -> (
        match response with
        | Error (`Request_failed err) -> (
            match Caqti_error.cause (`Request_failed err) with
            | `Unique_violation ->
                f (retries_lefts - 1) >>= fun x -> aux x (retries_lefts - 1)
            | _ -> Lwt.return response)
        | Error (`Response_failed err) -> (
            match
              (Caqti_error.cause (`Response_failed err), Uri.scheme err.uri)
            with
            | `Integrity_constraint_violation__don't_match, Some "sqlite3" ->
                (* The driver sqlite3 is less precise on error, so we are more permissive *)
                f (retries_lefts - 1) >>= fun x -> aux x (retries_lefts - 1)
            | _ -> Lwt.return response)
        | _ -> Lwt.return response)
  in
  f (number_tries - 1) >>= fun x -> aux x (number_tries - 1)

(** Fonction de test pour comprendre comment utiliser une database *)
let test db =
  (let (module Db : Caqti_lwt.CONNECTION) = db in
   match Caqti_driver_info.dialect_tag Db.driver_info with
   | `Sqlite -> print_endline "hello sqlite !"
   | _ -> ());
  (* Examples of statement execution: Create and populate the register. *)
  Queries.ensure_calendars_table db >>=? fun () ->
  Queries.ensure_tokens_table db >>=? fun () ->
  try_while_unique_violation
    (fun n ->
      Printf.printf "retry_lefts=%d\n" n;
      Queries.reg_token db "pisentt" (Crypto_rng_uid.random_str_20 ()))
    5

type error_t =
  [ `Calendar_does_not_exist
  | `No_saved_token_for_user
  | `Internal_database_error
  | `Connection_database_error ]

(** function to print caqti error and send back if it is a connection error
    (the final user may have misconfigured the program)
    or an internal error (problem with query etc..., not the fault of final user)
    @param err the error raised by any query function
    @return one of Error `Internal_database_error or Error `Connection_database_error *)
let handle_caqti_error (err : Caqti_error.t) =
  Lwt_io.eprintl (Caqti_error.show err) >>= fun () ->
  match err with
  | `Connect_failed _ | `Connect_rejected _ | `Load_failed _ | `Load_rejected _
    ->
      Lwt.return (Error `Connection_database_error)
  | _ -> Lwt.return (Error `Internal_database_error)

(** Get one churros token for the user owning the calendar which uid is calendar_uid.
    @param calendar_uid uid of the calendar for which we need a churros token
 *)
let get_token_from_calendar_uid calendar_uid =
  let aux db =
    Queries.select_user_from_calendar db calendar_uid >>= function
    | Ok (Some churros_uid) -> (
        Queries.select_token db churros_uid >>= function
        | Ok (Some token) ->
            Queries.update_calendar_last_access_date db calendar_uid
            >>=? fun () -> Lwt.return (Ok token)
        | Ok None -> Lwt.return (Error `No_saved_token_for_user)
        | Error err -> Lwt.return (Error err))
    | Ok None -> Lwt.return (Error `Calendar_does_not_exist)
    | Error err -> Lwt.return (Error err)
  in
  Lwt_main.run
    (Caqti_lwt_unix.with_connection (Uri.of_string (Queries.get_uri ())) aux
     >>= function
     | Ok token -> Lwt.return (Ok token)
     | Error `Calendar_does_not_exist ->
         Lwt.return (Error `Calendar_does_not_exist)
     | Error `No_saved_token_for_user ->
         Lwt.return (Error `No_saved_token_for_user)
     | Error (#Caqti_error.t as err) -> handle_caqti_error err)

let main () =
  Lwt_main.run
    (Caqti_lwt_unix.with_connection (Uri.of_string (Queries.get_uri ())) test
     >>= function
     | Ok () -> Lwt.return (Ok ())
     | Error (#Caqti_error.t as err) -> handle_caqti_error err)
