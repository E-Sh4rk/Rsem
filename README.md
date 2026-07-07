# Rsem

Rsem is a work-in-progress static type-checker for the R language.
See [Typr](https://github.com/PRL-PRG/typr) for more info.

## Install

We plan to integrate Rsem into the [Typr](https://github.com/PRL-PRG/typr) package.

For now, it must be installed in standalone by following these instructions (only tested on Linux).

1. Installing the OCaml Package Manager [OPAM](https://opam.ocaml.org/), and set up an OCaml 5.3.0 environment:
```
opam switch create typr 5.3.0
eval $(opam env --switch=typr)
```

2. Installing the parser dependencies by following the instructions on [our fork](https://github.com/E-Sh4rk/r-parser/tree/main) of [ocaml-tree-sitter-semgrep](https://github.com/semgrep/ocaml-tree-sitter-semgrep).

3. You may need to export treesitter directories: 
```
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/.../r-parser/core/tree-sitter/lib/
export TREESITTER_INCDIR=/.../r-parser/core/tree-sitter/include/
export TREESITTER_LIBDIR=/.../r-parser/core/tree-sitter/lib/
```

4. Installing this project dependencies, and building it:
```
make deps
make
```

## Acknowledgments

This work is supported by the Czech Ministry of Education, Youth and Sports under program ERC-CZ, grant agreement LL2325, as well as by the Czech Science Foundation Grant No. 23-07580X.
