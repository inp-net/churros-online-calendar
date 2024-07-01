type error_t =
  [ `Calendar_does_not_exist  (** no calendar with this uid found *)
  | `No_saved_token_for_user
    (** no token for this user found (they might all have expired, the user need to reconnect) *)
  | `Internal_database_error
    (** error raised by caqti, might indicate an error in the program, not user's fault *)
  | `Connection_database_error
    (** cannot connect to the database, might indicate an error in configuration, probably user's fault *)
  | `Token_already_exist
    (** the same token as already been registered to an user in the tokens table *)
  ]
(** Error that can be send back by the module *)

val ensure_tables_exist :
  unit ->
  (unit, [> `Connection_database_error | `Internal_database_error ]) result
  Lwt.t
(** Create all table used by the program if they don't exist, run it during init.
       Good way to verify the connection to the database is ok

   Table calendars:
     - churros_uid (UNIQUE, PRIMARY), the uid of the owner of the calendar
     - calendar_uid (UNIQUE), the uid of the calendar (used in the calendar url)
     - last_access_date, the date of the last access of the value.
     (Updated when we access a calendar by its uid but not when we retrieve the calendar link from the churros_uid)
     (module Caqti_lwt.CONNECTION) ->
       (unit, [> Caqti_error.call_or_retrieve ]) result Lwt.t Lwt.t

   Table tokens:
     - churros_token (UNIQUE, PRIMARY), a valid token to connect to churros
     - churros_uid, the uid of the owner of the account
     - creation_date, the date of the creation of the row
     *)

val get_token_from_calendar_uid :
  string ->
  ( string,
    [> `Calendar_does_not_exist
    | `Connection_database_error
    | `Internal_database_error
    | `No_saved_token_for_user ] )
  result
  Lwt.t

(** Get one churros token for the user owning the calendar which uid is calendar_uid.
    @param calendar_uid uid of the calendar for which we need a churros token
 *)

val get_user_calendar :
  string ->
  (string, [> `Connection_database_error | `Internal_database_error ]) result
  Lwt.t
(** get the calendar uid for a user, if it does not exist, a new calendar
    will be created
    @param churros_uid the user for which request a calendar uid
    @return the uid of the existing calendar (if one exist yet) or a new one
 *)

val register_user_token :
  string ->
  string ->
  ( unit,
    [> `Connection_database_error
    | `Internal_database_error
    | `Token_already_exist ] )
  result
  Lwt.t
(** register a new token for an user to connect to churros as the user
    @param churros_uid the user that own the token
    @param churros_token the token that allow to connect as the user to churros
 *)
