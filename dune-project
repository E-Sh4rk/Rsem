(lang dune 3.13)
(name rsem)
(using menhir 3.0)

(generate_opam_files true)

(authors "Mickael Laurent")

(maintainers "Mickael Laurent")

(homepage "https://github.com/E-Sh4rk/Rsem")

(bug_reports "https://github.com/E-Sh4rk/Rsem/issues")

(license "MIT")

(package
 (name rsem)
 (synopsis "A static type-checker for R")
 (depends (ocaml (>= 5.3.0)) dune mlsem rstt-repl sstt)
)
