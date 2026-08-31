# ========== S3 dispatch ==========

# Constructors of classed values (signature only).
#| sq_new : () -> dbl1<square>
#| ci_new : () -> dbl1<circle>

# The generic, with its default overload.
#| area : ( shape:dbl1 ) -> dbl1
area <- function(shape) 0

# `new area.square` removes the values of class `square` from the domain of the
# first parameter of every overload declared so far for `area`, and the
# signature below is added as a new overload of `area` whose first parameter is
# restricted to the values of class `square`.
#| new area.square
#| area.square : ( shape:dbl1 ) -> chr1
area.square <- function(shape) "square"

#| new area.circle
#| area.circle : ( shape:dbl1 ) -> lgl1
area.circle <- function(shape) TRUE

# Dispatch, positionally and by name.
a_square <- area(sq_new())
a_circle <- area(ci_new())
a_default <- area(0)
a_named <- area(shape = sq_new())

# A method can also be called directly.
a_direct <- area.square(sq_new())
