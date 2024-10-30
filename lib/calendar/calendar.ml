exception Invalid_format of string

(** Parse a churros event in json format to a native ocaml type *)
module ChurrosEventParser = struct
  type t_organizer = { name : string }
  [@@deriving yojson] [@@yojson.allow_extra_fields]

  type t = {
    title : string;
    description : string;
    startsAt : string;
    endsAt : string;
    updatedAt : string;
    location : string;
    id : string;
    organizer : t_organizer;
    localID : string;
  }
  [@@deriving yojson] [@@yojson.allow_extra_fields]
  (** Ocaml type for a churros event *)

  (** Parse a json event to type t
      @param json the yojson object to parse
      @return Some event if the parsing was successful
      or None if there is an eror *)
  let parse json =
    try Some (t_of_yojson json)
    with Ppx_yojson_conv_lib__Yojson_conv.Of_yojson_error _ ->
      print_endline "log error";
      None
end

(** Convert churros date format to ics date format
    @param datetime a timestamp givent by churros api
    @return an ics compatible timestamp
 *)
let change_date_format (datetime : string) : string =
  let date =
    String.split_on_char 'T' datetime |> List.hd |> String.split_on_char '-'
  in
  let year, month, day = (List.nth date 0, List.nth date 1, List.nth date 2) in
  let time =
    String.split_on_char 'T' datetime
    |> List.tl |> List.hd |> String.split_on_char '.' |> List.hd
    |> String.split_on_char ':'
  in
  let hour, minute, second =
    (List.nth time 0, List.nth time 1, List.nth time 2)
  in
  year ^ month ^ day ^ "T" ^ hour ^ minute ^ second ^ "Z"

(** Convert a single event to ics
    @param event the event to convert to ics
    @return the ics event *)
let ics_of_event (event : ChurrosEventParser.t) : Ics.t_ics =
  Ics.ICS
    [
      { key = "BEGIN"; value = "VEVENT" };
      { key = "UID"; value = event.id };
      { key = "DTSTAMP"; value = change_date_format event.updatedAt };
      { key = "DTSTART"; value = change_date_format event.startsAt };
      { key = "DTEND"; value = change_date_format event.endsAt };
      {
        key = "SUMMARY";
        value = Printf.sprintf "%s (%s)" event.title event.organizer.name;
      };
      { key = "LOCATION"; value = event.location };
      { key = "DESCRIPTION"; value = Printf.sprintf "%s\n\n\nPlus d'infos: https://churros.inpt.fr/events/%s" event.description event.localID };
      { key = "END"; value = "VEVENT" };
    ]

let events_json_list (json_txt : string) :
    (ChurrosEventParser.t list, unit) result =
  let ( --> ) a b = Yojson.Safe.Util.member b a in
  try
    Yojson.Safe.from_string json_txt --> "data" --> "events" --> "nodes"
    |> Yojson.Safe.Util.to_list
    |> fun l ->
    Ok
      (List.fold_left
         (fun acc x ->
           ChurrosEventParser.parse x |> function
           | None -> acc
           | Some y -> y :: acc)
         [] l)
  with Yojson.Json_error _ | Yojson.Safe.Util.Type_error _ -> Error ()

(** Convert a json string to an Ics
    @param json_txt the json string
    @return Ok ics_string if the json is correct or Error () *)
let ics_of_json (json_txt : string) : (string, 'a) result =
  match events_json_list json_txt with
  | Error () -> Error ()
  | Ok l ->
      Ok
        (Ics.flatten
           (Ics.ICS
              [
                { key = "BEGIN"; value = "VCALENDAR" };
                { key = "METHOD"; value = "REQUEST" };
                { key = "PRODID"; value = "-//CHURROS" };
                { key = "VERSION"; value = "2.0" };
                { key = "CALSCALE"; value = "GREGORIAN" };
              ]
            :: List.map ics_of_event l
           @ [ Ics.ICS [ { key = "END"; value = "VCALENDAR" } ] ])
        |> Ics.print_ics)
