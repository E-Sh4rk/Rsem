# ========== S3 dispatch ==========

# The class-overloads are declared first, as they define the class hierarchy:
# `new area @ square` makes `square` implement the method class `@area`, and
# must come before any type mentions `square`. They also restrict the
# signatures of `area`: the first parameter of a signature of `area` excludes
# the classes of the class-overloads that take precedence over it (all of them
# for the generic itself, the ones declared later for a class-overload), and
# the signature of the method `area.square` is also added as an overload of
# `area`, whose first parameter is restricted to the values of class `square`.
#| new area @ square
#| new area @ circle

# Constructors of classed values (signature only).
#| sq_new : () -> dbl1<square>
#| ci_new : () -> dbl1<circle>

# The generic, with its default overload.
#| area : ( shape:dbl1 ) -> dbl1
area <- function(shape) 0

#| area.square : ( shape:dbl1 ) -> chr1
area.square <- function(shape) "square"

#| area.circle : ( shape:dbl1 ) -> lgl1
area.circle <- function(shape) TRUE

# Dispatch, positionally and by name.
a_square <- area(sq_new())
a_circle <- area(ci_new())
a_default <- area(0)
a_named <- area(shape = sq_new())

# A method can also be called directly.
a_direct <- area.square(sq_new())
