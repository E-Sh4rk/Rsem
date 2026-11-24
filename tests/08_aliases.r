
#| numeric = <@is.numeric, @as.numeric, ...> | (INT|DBL)<~factor, ...>
#| character = <@as.character, ...> | vec

#| num_with_suffix : (x: 'a<`c> & numeric, suffix: character) -> 'a<num_with_suffix, `c>
num_with_suffix <- function(x, suffix) {
  stopifnot(is.numeric(x))
  suffix <- as.character(suffix)
  structure(x, suffix = suffix, class = "num_with_suffix")
}


