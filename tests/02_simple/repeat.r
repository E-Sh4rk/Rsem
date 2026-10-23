# `repeat` loops, exited with `break`. The body runs at least once, but is
# approximated by a loop that may run any number of times.
break_repeat <- function(n) {
  x <- 0
  i <- 0
  repeat {
    i <- i + 1
    if (i > n) break
    x <- i
  }
  x
}

next_repeat <- function(n) {
  i <- 0
  repeat {
    i <- i + 1
    if (i < n) next
    break
  }
  i
}

# A variable only bound inside the body is still a local of the function.
inner_repeat <- function() {
  repeat {
    y <- "a"
    break
  }
  y
}
