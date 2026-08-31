# ========== Annotations of non-top-level variables ==========

# `#| fun::var : t` annotates the variable `var` local to the top-level
# function `fun`: `x` is given the type `dbl` instead of the singleton type of
# the value it is initialized with.
#| annot_local::x : dbl
annot_local <- function() {
  x <- 42
  x
}

# Without the annotation, the singleton type is kept.
annot_none <- function() {
  x <- 42
  x
}

# The same annotation can be written inside the definition of the function.
annot_inside <- function() {
  #| x : dbl
  x <- 42
  x
}

# Parameters can be annotated too.
#| annot_param::a : dbl
annot_param <- function(a) a

# The annotation widens a variable assigned in a loop.
#| annot_loop::acc : dbl
annot_loop <- function(n) {
  #| i : dbl
  i <- n
  acc <- 0
  while (i > 0) {
    acc <- acc + i
    i <- i - 1
  }
  acc
}

# A local variable holding a function can be annotated as well.
#| annot_fun::inner : (x:dbl) -> dbl
annot_fun <- function() {
  inner <- function(x) x + 1
  inner(2)
}

# The annotations of a function are dropped once it has been typed, so a
# top-level definition shadowing it can declare its own.
#| annot_shadow::x : dbl
annot_shadow <- function() { x <- 42 ; x }
#| annot_shadow::x : lgl
annot_shadow <- function() { x <- TRUE ; x }

# The value assigned to an annotated variable is checked against its type.
#| annot_err::x : lgl
annot_err <- function() {
  x <- 42
  x
}

# ========== Dot-prefixed names ==========

# R identifiers may start with a dot, and so may the name on the left of an
# annotation: `.Platform`, `.Machine` and the `.onLoad` hooks are exactly the
# names a prelude needs to declare.
#| .dot_global : dbl
#| .dot_fun : (x:dbl) -> CHR1
.dot_fun <- function(x) "s"

annot_dot_use <- function() .dot_fun(.dot_global)

# A dot-named local of a dot-named function.
#| .dot_local::.x : dbl
.dot_local <- function() {
  .x <- 42
  .x
}
