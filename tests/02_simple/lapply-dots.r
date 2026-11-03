
#| execute : ( n: dbl ) -> { dbl }
# The local function is annotated, as for lapply.r.
#| execute/f : (x: INT1<>, y: dbl) -> dbl
execute <- function(n) {
  x <- 1:n
  f <- function(x, y) x + 1.5 * y
  a <- n / 2
  lapply(x, f, y=a)
}
