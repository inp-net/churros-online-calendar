(* TODO

   val ensure_tables_exist : unit -> unit
   (** Create all table used by the program if they don't exist.

   Table calendars:
     - churros_uid (UNIQUE, PRIMARY), the uid of the owner of the calendar
     - calendar_uid (UNIQUE), the uid of the calendar (used in the calendar url)
     - last_access_date, the date of the last access of the value.
     (Updated when we access a calendar by its uid but not when we retrieve the calendar link from the churros_uid)
     (module Caqti_lwt.CONNECTION) ->
       (unit, [> Caqti_error.call_or_retrieve ]) result Lwt.t

   Table tokens
     - churros_token (UNIQUE, PRIMARY), a valid token to connect to churros
     - churros_uid, the uid of the owner of the account
     - creation_date, the date of the creation of the row
     *)
*)

type error_t =
  [ `Calendar_does_not_exist  (** no calendar with this uid found *)
  | `No_saved_token_for_user
    (** no token for this user found (they might all have expired, the user need to reconnect) *)
  | `Internal_database_error
    (** error raised by caqti, might indicate an error in the program, not user's fault *)
  | `Connection_database_error
    (** cannot connect to the database, might indicate an error in configuration, probably user's fault *)
  ]
(** Error that can be send back by the module *)

val get_token_from_calendar_uid : string -> (string, error_t) result
(** Get one churros token for the user owning the calendar which uid is calendar_uid.
    @param calendar_uid uid of the calendar for which we need a churros token
 *)

val main :
  unit ->
  (unit, [> `Internal_database_error | `Connection_database_error ]) result
