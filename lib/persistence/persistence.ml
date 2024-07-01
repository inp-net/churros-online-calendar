open Lwt.Infix

(** define the maximum number of retries allowed in case of SQL unique
 constraint error.
 example: the number of times we can try to generate a new random uid
 if the first one already exist in the table
 *)
let max_number_retries_on_collision = 5

type error_t =
  [ `Calendar_does_not_exist
  | `No_saved_token_for_user
  | `Internal_database_error
  | `Connection_database_error ]

(** operator that execute the next function only if the previous one return Ok
    and pass the result to the new function if so *)
let ( >>=? ) m f =
  m >>= function Ok x -> f x | Error err -> Lwt.return (Error err)

(** Run a fonction at most (number_retries + 1) times until there is not an SQL
    unique_constraint error 
    if there is another SQL error, the function stop and the error is returned.

    @param f the function that perform a sql query that can have collisions
    with existing values in the database,
        it takes the number of left retries at unique parameter
    @param number_tries the maximum number of times the f function can be called
    @return the same as the last execution of f
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

(** Create all table used by the program if they don't exist, run it during init.
       Good way to verify the connection to the database is ok

   Table calendars:
     - churros_uid (UNIQUE, PRIMARY), the uid of the owner of the calendar
     - calendar_uid (UNIQUE), the uid of the calendar (used in the calendar url)
     - last_access_date, the date of the last access of the value.
     (Updated when we access a calendar by its uid but not when we retrieve the calendar link from the churros_uid)
     (module Caqti_lwt.CONNECTION) ->
       (unit, [> Caqti_error.call_or_retrieve ]) result Lwt.t

   Table tokens:
     - churros_token (UNIQUE, PRIMARY), a valid token to connect to churros
     - churros_uid, the uid of the owner of the account
     - creation_date, the date of the creation of the row
     *)
let ensure_tables_exist () =
  Lwt_main.run
    (Caqti_lwt_unix.with_connection
       (Uri.of_string (Queries.get_uri ()))
       (fun db ->
         Queries.ensure_calendars_table db >>=? fun () ->
         Queries.ensure_tokens_table db)
     >>= function
     | Ok () -> Lwt.return (Ok ())
     | Error (#Caqti_error.t as err) -> handle_caqti_error err)

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

(** get the calendar uid for a user, if it does not exist, a new calendar
    will be created
    @param churros_uid the user for which request a calendar uid
    @return the uid of the existing calendar (if one exist yet) or a new one
 *)
let get_user_calendar churros_uid =
  let aux db =
    Queries.select_calendar db churros_uid >>= function
    | Ok (Some calendar_uid) -> Lwt.return (Ok calendar_uid)
    | Ok None ->
        try_while_unique_violation
          (fun _ ->
            let new_uid = Crypto_rng_uid.random_str_20 () in
            Queries.reg_calendar db churros_uid new_uid >>= function
            | Ok () -> Lwt.return (Ok new_uid)
            | Error err -> Lwt.return (Error err))
          max_number_retries_on_collision
    | Error err -> Lwt.return (Error err)
  in
  Lwt_main.run
    (Caqti_lwt_unix.with_connection (Uri.of_string (Queries.get_uri ())) aux
     >>= function
     | Ok calendar_uid -> Lwt.return (Ok calendar_uid)
     | Error (#Caqti_error.t as err) -> handle_caqti_error err)

(** register a new token for an user to connect to churros as the user
    @param churros_uid the user that own the token
    @param churros_token the token that allow to connect as the user to churros
 *)
let register_user_token churros_uid churros_token =
  Lwt_main.run
    (Caqti_lwt_unix.with_connection
       (Uri.of_string (Queries.get_uri ()))
       (fun db -> Queries.reg_token db churros_uid churros_token)
     >>= function
     | Ok () -> Lwt.return (Ok ())
     | Error (#Caqti_error.t as err) -> handle_caqti_error err)

(*
let report_error = function
  | Ok () -> Lwt.return_unit
 | Error err ->
     Lwt_io.eprintl (Caqti_error.show err) >|= fun () -> exit 69

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

let main () =
  Lwt_main.run
    (Caqti_lwt_unix.with_connection (Uri.of_string (Queries.get_uri ())) test
     >>= function
     | Ok () -> Lwt.return (Ok ())
     | Error (#Caqti_error.t as err) -> handle_caqti_error err)
*)
