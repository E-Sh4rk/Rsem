# ========== S3 dispatch ==========

# The class-overloads are declared first, as they define the class hierarchy:
# `new area @ square` makes `square` implement the method class `@area`, and
# must come before any type mentions `square`. They also restrict the
# signatures of `area`: the first parameter of a signature of `area` excludes
# the classes of the class-overloads that take precedence over it (for the
# generic itself all of them, i.e. the method class `@area`; for a
# class-overload, the ones declared after it), and the signature of the method
# `area.square` is also added as an overload of `area`, whose first parameter
# is restricted to the values of class `square`.
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

# ========== Method classes ==========

# `@area` stands for the values whose class implements `area`: here, `square`
# and `circle`. A function can ask for one of them.
#| any_shape : (s: dbl1<@area, ...>) -> vec1
any_shape <- function(s) area(s)
m_square <- any_shape(sq_new())
m_circle <- any_shape(ci_new())
m_default <- any_shape(0)

# The default signature of `area` excludes `@area`.
#| default_area : (s: dbl1<~@area, ...>) -> dbl1
default_area <- function(s) area(s)

# ========== Methods of base and stats ==========

# Dates: arithmetic with numbers gives dates, the difference of two dates a
# `difftime` (cf. "S3 methods" in sigs/base.R).
today <- as.Date("2026-11-03")
tomorrow <- today + 1
yesterday <- today - 1
span <- tomorrow - yesterday
twice <- span * 2
halved <- span / 2
span_units <- units(span)
dates <- c(today, tomorrow)
first_date <- dates[1]
second_date <- dates[[2]]

# Date-times.
t_start <- Sys.time()
t_later <- t_start + 60
t_elapsed <- Sys.time() - t_start

# Factors keep their class and levels through subsets, and their arithmetic
# gives `NA`.
fct <- factor(c("lo", "hi", "lo"))
fct_first <- fct[1]
fct_second <- fct[[2]]
fct_levels <- levels(fct)
fct_plus <- fct + 1

# Errors of R: negating a date, adding two dates, dividing by a `difftime`.
err_neg <- -today
err_add <- today + tomorrow
err_div <- span / span

# The default methods: a value of known class only uses the signatures that
# apply to it, and keeps (or drops) its classes as R does.
plain <- 1 + 2
plain_neg <- -plain
plain_sub <- c(1, 2)[1]
plain_list <- list(a = 1, b = "b")[["b"]]
plain_round <- round(plain)

# A value of unknown class may have any of the classes with methods: each
# method gives its own result.
#| next_val : (x: dbl1) -> dbl1
next_val <- function(x) x + 1
#| scaled : (x: dbl) -> dbl
scaled <- function(x) x * 2

# Time series, from sigs/stats.R: their arithmetic keeps the class, and a
# subset drops it.
series <- ts(c(1, 2, 3), start = 2000)
series_twice <- series * 2
series_first <- series[1]
