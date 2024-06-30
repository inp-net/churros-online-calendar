let () = Mirage_crypto_rng_lwt.initialize (module Mirage_crypto_rng.Fortuna)

(** Generate a new random string of 20 characters using a crypto prng; the generated string is uri safe *)
let random_str_20 () =
  (* prendre un multiple de 3 comme ça le nombre de bits est multiple de 6
     et pas besoin de padding pour passer en base64 *)
  Mirage_crypto_rng.generate 15 |> fun x ->
  Base64.encode_string ~alphabet:Base64.uri_safe_alphabet (Cstruct.to_string x)
