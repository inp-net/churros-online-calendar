type t_assoc = { key : string; value : string }
and t_ics = ICS of t_assoc list [@@deriving show { with_path = false }]

(** Split a sequence every n elements
    @param n the number of elements in each seq in output string
    @param seq the sequence to split
    @return a list of sequence of maximum n elements with the same content as original sequence
 *)
let rec split_every_n_elements (n : int) (seq : 'a Seq.t) : 'a Seq.t list =
  match Seq.is_empty seq with
  | true -> []
  | false -> Seq.take n seq :: split_every_n_elements n (Seq.drop n seq)

(** Return true if the given character is a whitespace char *)
let is_whitespace = function '\n' | '\r' | '\x0c' | '\t' -> true | _ -> false

(** Return true if the given string contains only whitespace chars *)
let is_string_whitespace s =
  String.to_seq s |> Seq.map is_whitespace |> Seq.fold_left ( && ) true

(** Wrap lines every 75 chars with CLRF + ' ' sequences to match ICS standard
    @param text_line the string that may need modifications
    @return a string matching the ICS standard, ready to be printed *)
let ics_line_wrap text_line =
  split_every_n_elements 74 (Bytes.to_seq (String.to_bytes text_line))
  |> List.map String.of_seq
  |> List.filter (fun x -> not (is_string_whitespace x))
     (* remove empty lines *)
  |> String.concat "\r\n " (* Don't forget the ' ' ! *)

let rec print_ics = function
  | ICS [] -> ""
  | ICS (x :: xs) ->
      (* don't forget to limit lines length to 75 characters *)
      ics_line_wrap
        (x.key ^ ":"
        ^ (String.split_on_char '\n' x.value
          |> String.concat "\\n" (* escape \n in string value *)))
      ^ "\r\n" (* lines ends with CLRF sequences in ICS standard *)
      ^ print_ics (ICS xs)

let flatten ics_list =
  ICS (List.flatten (List.map (function ICS l -> l) ics_list))
