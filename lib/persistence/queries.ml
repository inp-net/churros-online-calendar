(** If we can get access to some env vars, we construct a special URI to use our local DB.
   Otherwise, we return a default URI, which is "sqlite3:///tmp/test.sql". We would then use our system DB. *)
let get_uri () =
  match Sys.getenv_opt "DB_URI" with
  | Some s -> s
  | None -> "sqlite3:///tmp/test.sql"

let connect () =
  let uri = get_uri () in
  Caqti_lwt_unix.connect (Uri.of_string uri)

module Q = struct
  open Caqti_request.Infix
  open Caqti_type.Std

  let ensure_calendars_table =
    (unit ->. unit)
    @@ {eos|
      CREATE TABLE IF NOT EXISTS calendars (
        churros_uid VARCHAR(50) NOT NULL PRIMARY KEY, 
        calendar_uid VARCHAR (50) NOT NULL UNIQUE,
        last_access_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    |eos}

  let ensure_tokens_table =
    (unit ->. unit)
    @@ {eos|
      CREATE TABLE IF NOT EXISTS tokens (
        churros_uid VARCHAR (50) NOT NULL,
        churros_token VARCHAR(50) NOT NULL PRIMARY KEY, 
        creation_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    |eos}

  let reg_calendar =
    (t2 string string ->. unit)
    @@ "INSERT INTO calendars (churros_uid, calendar_uid) VALUES (?, ?)"

  let reg_token =
    (t2 string string ->. unit)
    @@ "INSERT INTO tokens (churros_uid, churros_token) VALUES (?, ?)"

  let select_calendar =
    (string ->? string)
    @@ "SELECT calendar_uid FROM calendars WHERE churros_uid = ?"

  let select_user_from_calendar =
    (string ->? string)
    @@ "SELECT churros_uid FROM calendars WHERE calendar_uid = ?"

  (* select last created token if multiple possible choices *)
  let select_token =
    (string ->? string)
    @@ "SELECT churros_token FROM tokens WHERE churros_uid = ? ORDER BY \
        creation_date DESC LIMIT 1"

  let update_calendar_last_access_date =
    (string ->. unit)
    @@ "UPDATE calendars SET last_access_date = CURRENT_TIMESTAMP WHERE \
        calendar_uid = ?"
end

(* Db.exec runs a statement which must not return any rows.  Errors are
 * reported as exceptions. *)

(** create the table of calendars if it does not exist yet *)
let ensure_calendars_table (module Db : Caqti_lwt.CONNECTION) =
  Db.exec Q.ensure_calendars_table ()

(** create the table of tokens if it does not exist yet *)
let ensure_tokens_table (module Db : Caqti_lwt.CONNECTION) =
  Db.exec Q.ensure_tokens_table ()

(** query to register a calendar to an user 
    @param db a connection to the database
    @param churros_uid the owner of the new calendar (must be a new user)
    @param calendar_uid the uid of the new calendar (must be a new uid)
    @return Error err if the churros_uid is not unique or the calendar_uid is not unique
    or another database error, Ok () if the request was successfull
 *)
let reg_calendar (module Db : Caqti_lwt.CONNECTION) churros_uid calendar_uid =
  Db.exec Q.reg_calendar (churros_uid, calendar_uid)

(** query to register a token to an user 
    @param db a connection to the database
    @param churros_uid the owner of the new token
    @param churros_token the token of the new churros connection (must be a new token)
    @return Error err if the churros_token is not unique
    or another database error, Ok () if the request was successfull
 *)
let reg_token (module Db : Caqti_lwt.CONNECTION) churros_uid churros_token =
  Db.exec Q.reg_token (churros_uid, churros_token)

(* Db.find runs a query which must return at most one row.  The result is a
 * option, since it's common to seach for entries which don't exist. *)

(** query to get the calendar_uid for a user
    @param db a connection to the database
    @param churros_uid the user who request a calendar
    @return Some uid if a calendar exist or None
 *)
let select_calendar (module Db : Caqti_lwt.CONNECTION) churros_uid =
  Db.find_opt Q.select_calendar churros_uid

(** get the owner of a calandar
    @param calendar_uid the calendar for which we search the owner
    @return Some churros_uid if the calendar exist or None
 *)
let select_user_from_calendar (module Db : Caqti_lwt.CONNECTION) calendar_uid =
  Db.find_opt Q.select_user_from_calendar calendar_uid

(** get the last created token for an user
    @param churros_uid the user who request a token to connect to churros
    @return Some token if at least one token exist or None if no token exist
 *)
let select_token (module Db : Caqti_lwt.CONNECTION) churros_uid =
  Db.find_opt Q.select_token churros_uid

(** update last_access_date value for the calendar passed in parameter with current date
    @param calendar_uid the calendar to update
 *)
let update_calendar_last_access_date (module Db : Caqti_lwt.CONNECTION)
    calendar_uid =
  Db.exec Q.update_calendar_last_access_date calendar_uid
