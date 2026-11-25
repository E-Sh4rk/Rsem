# ========== Annotations of non-top-level variables ==========

# `#| fun/var : t` annotates the variable `var` local to the top-level
# function `fun`: `x` is given the type `dbl` instead of the singleton type of
# the value it is initialized with.
#| annot_local/x : dbl
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
#| annot_param/a : dbl
annot_param <- function(a) a

# The annotation widens a variable assigned in a loop.
#| annot_loop/acc : dbl<>
annot_loop <- function(n) {
  #| i : dbl<>
  i <- n
  acc <- 0
  while (i > 0) {
    acc <- acc + i
    i <- i - 1
  }
  acc
}

# A local variable holding a function can be annotated as well.
#| annot_fun/inner : (x:dbl<>) -> dbl
annot_fun <- function() {
  inner <- function(x) x + 1
  inner(2)
}

# The annotations of a function are dropped once it has been typed, so a
# top-level definition shadowing it can declare its own.
#| annot_shadow/x : dbl
annot_shadow <- function() { x <- 42 ; x }
#| annot_shadow/x : lgl
annot_shadow <- function() { x <- TRUE ; x }

# The value assigned to an annotated variable is checked against its type.
#| annot_err/x : lgl
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
#| .dot_local/.x : dbl
.dot_local <- function() {
  .x <- 42
  .x
}

# ========== Operator names ==========

# An operator is annotated by parenthesising it. The alphabet covers `^`
# (declared in 00_defs.r) and `~`, which builds a formula.
#| (~) : ( e1:any, e2:any ) -> any

annot_pow <- function(x) x^2
annot_tilde <- function(x, y) x ~ y

# ========== Intersections of arrows ==========

# A signature can be an intersection of arrows, written with `&&` (whose
# precedence is lower than the one of `->`). Each arrow is checked
# separately (`inter_bad` is expected to fail, for its second arrow), and the
# arrows of a signature are kept together when it is applied in inference
# mode, whereas two signatures declared apart are two overloads.
#| inter_id : (x: dbl1) -> dbl1 && (x: lgl1) -> lgl1
inter_id <- function(x) x

#| inter_bad : (x: dbl1) -> dbl1 && (x: chr1) -> dbl1
inter_bad <- function(x) x

inter_use <- function(y) inter_id(y)

# Its arrows may have label variables, local to each of them.
#| inter_get : (x: {#k: 'a, any}, k: #k) -> 'a && (x: null, k: chr1) -> null
inter_get <- function(x, k) x[[k]]
inter_get_a <- inter_get(list(a = 1), "a")
inter_get_null <- inter_get(NULL, "a")

# ========== Signatures incompatible with their definition ==========

# The parameters of a signature must be the ones of the definition it annotates:
# otherwise, the definition is rejected before its body is typed.
#| params_renamed : (x: dbl, suff: lgl) -> dbl
params_renamed <- function(x, suffix) x

#| params_missing : (x: dbl, ...: any) -> dbl
params_missing <- function(x) x

# Only the arrow that is incompatible is reported.
#| params_arrow : (x: dbl) -> dbl && (y: lgl) -> lgl
params_arrow <- function(x) x

# Parameters that have a default value, or that are in `...`, can be omitted.
#| params_omitted : (x: dbl) -> dbl
params_omitted <- function(x, y = 2, ...) x

# This only concerns the parameters of the definition itself, not the ones of
# the functions in its body.
#| params_body : (x: dbl) -> any
params_body <- function(x) function() x
