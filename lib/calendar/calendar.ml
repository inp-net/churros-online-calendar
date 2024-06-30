exception Invalid_format of string

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

let rec ics_of_json (json : Json.t_json) : Ics.t_ics =
  match json with
  | Json.J_Object [] -> Ics.ICS []
  | Json.J_Object (h :: t) -> (
      let (Ics.ICS tail) =
        try ics_of_json (Json.J_Object t) with Invalid_format _ -> Ics.ICS []
      in
      let (Ics.ICS h_value) =
        try ics_of_json h.value with Invalid_format _ -> Ics.ICS []
      in
      let h_key = h.key in
      match h_key with
      | "data" ->
          let (Ics.ICS ending) =
            Ics.ICS [ { key = "END"; value = "VCALENDAR" } ]
          in
          Ics.ICS
            ({ key = "BEGIN"; value = "VCALENDAR" }
            :: { key = "METHOD"; value = "REQUEST" }
            :: { key = "PRODID"; value = "-//CHURROS" }
            :: { key = "VERSION"; value = "2.0" }
            :: { key = "CALSCALE"; value = "GREGORIAN" }
            :: (h_value @ ending))
      | "uid" -> (
          match h.value with
          | Json.J_String uid -> Ics.ICS ({ key = "UID"; value = uid } :: tail)
          | _ -> raise (Invalid_format "Invalid UID format"))
      | "startsAt" -> (
          match h.value with
          | Json.J_String date ->
              Ics.ICS
                ({ key = "DTSTART"; value = change_date_format date } :: tail)
          | _ -> raise (Invalid_format "Invalid date format"))
      | "endsAt" -> (
          match h.value with
          | Json.J_String date ->
              Ics.ICS
                ({ key = "DTEND"; value = change_date_format date } :: tail)
          | _ -> raise (Invalid_format "Invalid date format"))
      | "location" -> (
          match h.value with
          | Json.J_String location ->
              Ics.ICS ({ key = "LOCATION"; value = location } :: tail)
          | _ -> raise (Invalid_format "Invalid location format"))
      | "title" -> (
          match h.value with
          | Json.J_String title ->
              Ics.ICS ({ key = "SUMMARY"; value = title } :: tail)
          | _ -> raise (Invalid_format "Invalid title format"))
      | "description" -> (
          match h.value with
          | Json.J_String description ->
              Ics.ICS ({ key = "DESCRIPTION"; value = description } :: tail)
          | _ -> raise (Invalid_format "Invalid description format"))
      | _ -> Ics.ICS (tail @ h_value)
      (*Ics.ICS ({ key = h_key; value = "" }::(tail @ h_value))*))
  | Json.J_Array [] -> Ics.ICS []
  | Json.J_Array (h :: t) ->
      let (Ics.ICS tail) =
        try ics_of_json (Json.J_Array t) with Invalid_format _ -> Ics.ICS []
      in
      let (Ics.ICS h_value) =
        try ics_of_json h with Invalid_format _ -> Ics.ICS []
      in
      let (Ics.ICS h_value_with_header) =
        Ics.ICS
          ({ key = "BEGIN"; value = "VEVENT" }
          :: { key = "DTSTAMP"; value = "20240101T000000Z" }
          :: { key = "CREATED"; value = "20240101T000000Z" }
          :: { key = "LAST-MODIFIED"; value = "20240621T000000Z" }
          :: { key = "SEQUENCE"; value = "0" }
          :: h_value)
      in
      let (Ics.ICS tail_with_footer) =
        Ics.ICS ({ key = "END"; value = "VEVENT" } :: tail)
      in
      Ics.ICS (h_value_with_header @ tail_with_footer)
  | i -> raise (Invalid_format ("Invalid JSON input : " ^ Json.show_t_json i))
