# `break` and `next` inside a `for` loop. The loop body is wrapped in a BLoop
# block, as MLsem's own lowering of `while` does, so that the jump has a block
# to return to.
break_for <- function(n) {
  x <- 0
  for (i in 1:n) {
    if (i > 3) break
    x <- i
  }
  x
}

next_for <- function(n) {
  x <- 0
  for (i in 1:n) {
    if (i > 3) next
    x <- i
  }
  x
}

# The jump must escape the loop variable's assignment as well as the body, and
# the inner loop's `break` must not escape the outer one.
nested_break_for <- function(n) {
  x <- 0
  for (i in 1:n) {
    for (j in 1:n) break
    x <- i
  }
  x
}

# Over a sequence rather than a range.
break_for_seq <- function(l) {
  x <- 0
  for (e in l) break
  x
}
