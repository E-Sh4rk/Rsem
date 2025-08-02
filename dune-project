(lang dune 3.13)
(name typed-r)
(using menhir 3.0)

(generate_opam_files true)

(authors "Mickael Laurent")

(maintainers "Mickael Laurent")

(homepage "https://github.com/E-Sh4rk/typed-r")

(bug_reports "https://github.com/E-Sh4rk/typed-r/issues")

(license "MIT")

(package
 (name typed-r)
 (synopsis "A static type-checker for R")
 (depends (ocaml (>= 5.3.0)) dune mlsem sstt)
)
