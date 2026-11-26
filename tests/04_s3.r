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
#| method area
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
# and `circle`. A function can ask for one of them (`m_default` is expected to
# fail).
#| some_shape : (s: dbl1<@area, ...>) -> dbl1<@area, ...>
some_shape <- function(s) s
m_square <- some_shape(sq_new())
m_circle <- some_shape(ci_new())
m_default <- some_shape(0)

# `area` gives such a value the union of the results of its class-overloads:
# its other classes are unknown, and the class records do not respect the class
# hierarchy, so that `<@area, ...>` has values of neither `square` nor
# `circle`, which only the fallback signature of `area` covers (cf.
# `MetaEnv.sigs`).
#| any_shape : (s: dbl1<@area, ...>) -> vec1
any_shape <- function(s) area(s)

# The base signature of `area` excludes `@area`.
#| default_area : (s: dbl1<~@area, ...>) -> dbl1
default_area <- function(s) area(s)

# ========== Default method ==========

# The signature of a default method is also an overload of its generic, which
# applies to the values whose class has no class-overload (including those that
# have no class), or if there is no argument. The default method is not declared
# with `new`, `default` not being a class.
#| method scale2
#| new scale2 @ square
#| scale2 : (x: CHR1) -> CHR1
scale2 <- function(x) x
#| scale2.default : (x: (dbl | null)?) -> dbl
scale2.default <- function(x = 0) 0
#| scale2.square : (x: any) -> CHR1
scale2.square <- function(x) "square"
d_base <- scale2("a")
d_default <- scale2(0)
d_null <- scale2(NULL)
d_absent <- scale2()
d_circle <- scale2(ci_new())
d_square <- scale2(sq_new())
# It can be called directly on any value.
d_direct <- scale2.default(sq_new())
# The default method does not apply to `@scale2` (it is expected to fail).
#| d_unknown : (x: dbl1<@scale2, ...>) -> dbl
d_unknown <- function(x) scale2(x)

# When the type of an argument is inferred, the default method is only
# considered if the first argument certainly has no class-overload, as for `0`:
# `i_unknown` only has the types of the other signatures. An annotated function
# is checked with all the signatures.
i_unknown <- function(x) scale2(x)
#| method scale3
#| scale3.default : (x: dbl, y: any) -> lgl1
i_known <- function(y) scale3(0, y)
#| i_annot : (x: dbl1<>) -> dbl
i_annot <- function(x) scale2(x)

# The operators have no default method: this signature does not affect `*`
# (it is expected to fail).
#| (*.default) : (e1: list, e2: any) -> CHR1
d_op <- list(1) * 2

# The signature of a class-overload or of a default method may come before the
# ones of its generic, or be its only ones: the definition of the generic is then
# not checked (`g_other` is expected to fail).
#| method generic1
#| new generic1 @ square
#| generic1.square : (x: any) -> CHR1
#| generic1.default : (x: dbl) -> lgl1
generic1 <- function(x) UseMethod("generic1")
g_square <- generic1(sq_new())
g_default <- generic1(0)
g_other <- generic1("a")

# ========== Inferred generic ==========

# The type of these generics is inferred: the signatures of their methods are
# declared in another file (cf. 07_namespace.r), as the annotations of a file are
# treated before its definitions.
#| method inferred1
#| method inferred2
#| new inferred1 @ square
#| new inferred2 @ square
inferred1 <- function(x) x
inferred2 <- function(x) UseMethod("inferred2")

# ========== Inferred methods ==========

# The type inferred for a class-overload or a default method that has no
# signature is an overload of its generic, as a signature would be: the one of
# a class-overload is restricted to its class (and to the classes of the
# class-overloads declared after it, cf. `MetaEnv.sigs`), the one of a default
# method to the values whose class has no class-overload. R names the methods
# of the subsets `[.cls` and `[[.cls`, which are the class-overloads of `([])`
# and `([[]])`.
#| method inferred3
#| new inferred3 @ square
#| new inferred3 @ circle
#| new ([]) @ inf_rect
#| inf_rect_new : () -> dbl1<inf_rect>
inferred3 <- function(s) UseMethod("inferred3")
inferred3.square <- function(s) "square"
inferred3.circle <- function(s) 1L
inferred3.default <- function(s) TRUE
"[.inf_rect" <- function(x, i) "element"
im_square <- inferred3(sq_new())
im_circle <- inferred3(ci_new())
im_default <- inferred3(0)
im_unknown <- function(s) inferred3(s)
im_subset <- inf_rect_new()[1]

# ========== Literal classes ==========

# A class given as a literal string is the class of the result of `class<-`
# and `structure` (cf. their signatures in base.R): a value built that way is
# dispatched on it. A class that is not a literal string leaves the classes
# unknown.
lc_structure <- structure(list(side = 2), class = "square")
lc_assign <- function(x) { class(x) <- "circle" ; x }
lc_dispatch <- inferred3(structure(list(side = 2), class = "square"))
lc_unknown <- function(x, cl) { class(x) <- cl ; x }
lc_old <- function(x) { oldClass(x) <- "circle" ; x }
# A test of a literal class narrows (`inherits`, `methods::is`), and is decided
# by the type of the value when its classes are known.
lc_narrow <- function(x) if (inherits(x, "square")) x else NULL
lc_true <- inherits(lc_structure, "square")
lc_false <- inherits(lc_structure, "circle")
lc_is <- function(x) methods::is(x, "square")
lc_any <- function(x, cl) inherits(x, cl)

# ========== Return type of a method ==========

# The return type of a method can be declared. Its class-overloads must return a
# subtype of it (but not its other signatures), and it is the type given to a
# value of unknown class, rather than the union of the results of its
# class-overloads. It can mention classes whose class-overloads are declared
# afterward.
#| method label : CHR
#| method clone : dbl<square, ...> | dbl<circle, ...>
#| new label @ square
#| new label @ circle
#| new clone @ square

#| label : (x: dbl1) -> lgl1
#| label.square : (x: any) -> "square"
l_square <- label(sq_new())
l_default <- label(0)
#| l_unknown : (x: dbl1<@label, ...>) -> CHR
l_unknown <- function(x) label(x)
# The result may come from another class-overload (it is expected to fail).
#| l_precise : (x: dbl1<@label, ...>) -> "square"
l_precise <- function(x) label(x)

# A class-overload without signature: the type inferred for it is an overload
# of its method only if it complies with the return type of the method, which
# that of `label.circle` does not. `label` then gives a value of class `circle`
# that return type, and `label.circle` keeps its own type.
label.circle <- function(x) TRUE
l_circle <- label(ci_new())

#| clone : (x: dbl1) -> dbl1<circle>
#| clone.square : (x: any) -> dbl1<square>
c_unknown <- function(x) clone(x)

# Without class-overload, the return type still applies (here, the one of
# `base::as.character`): `chr_precise` is expected to fail.
#| chr_unknown : (x: <@as.character, ...>) -> CHR
chr_unknown <- function(x) as.character(x)
#| chr_precise : (x: <@as.character, ...>) -> empty
chr_precise <- function(x) as.character(x)

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

# A value of unknown class may have a class with a method: for it, only the
# fallback signature of `+` applies (cf. `MetaEnv.sigs`), whose result
# is the union of the results of the methods of `+` (e.g. those for `Date` or
# `difftime`), not `dbl1` (it is expected to fail). Its classes must be given,
# or none with `<>`.
#| next_val : (x: dbl1) -> dbl1
next_val <- function(x) x + 1
#| scaled : (x: dbl<>) -> dbl
scaled <- function(x) x * 2

# Time series, from sigs/stats.R: their arithmetic keeps the class, and a
# subset drops it.
series <- ts(c(1, 2, 3), start = 2000)
series_twice <- series * 2
series_first <- series[1]
