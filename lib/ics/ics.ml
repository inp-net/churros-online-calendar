type t_assoc = { key : string; value : string }
and t_ics = ICS of t_assoc list [@@deriving show { with_path = false }]

let rec print_ics = function
  | ICS [] -> ""
  | ICS (x :: xs) -> x.key ^ ":" ^ x.value ^ "\n" ^ print_ics (ICS xs)
