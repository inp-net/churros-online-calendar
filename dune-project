(lang dune 3.10)

(name churros_online_calendar)

(using menhir 2.1)

(generate_opam_files true)

(source
  (github inp-net/churros-online-calendar)
)

(authors "INP-net")

(maintainers "Theo Bessel" "Teo Pisenti")

(license LICENSE)

(documentation https://url/to/documentation)

(package
  (name churros_online_calendar)
  (synopsis "A program to export churros events to an online calendar.")
  (description "This program fetches churros API events and exports them to an online calendar using .ics files.")
  (depends (ocaml (>= 5.1)) dune)
  (tags
    (calendar ics churros)
  )
)
