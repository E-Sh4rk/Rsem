# The local function is annotated: inferring it for an unknown argument has to
# consider every class-overload of `+`, which makes the inference of `execute`
# too slow.
#| execute/f : (x: dbl1<>) -> DBL1<>
execute <- function(n) {
  x <- 1:n
  f <- function(x) x + 1.5
  lapply(x, f)
}
