# ========== Namespaces ==========

# `#| ns::name : t` declares the type of the name `name` of the namespace `ns`,
# as R code reaches it with `ns::name` (or `ns:::name`).
#| stats::median : (x:dbl) -> dbl1
#| stats::median : (x:CHR) -> CHR1
#| datasets::pi_approx : dbl1

ns_call <- function(x) stats::median(x)
ns_call_num <- function() stats::median(c(1, 2, 3))
ns_internal <- function(x) stats:::median(x)
ns_value <- function() datasets::pi_approx

# A string can name the function, as in R.
ns_string <- function(x) stats::"median"(x)

# A namespaced name is not affected by a local binding of the same name.
ns_shadow <- function(x) {
  median <- "not a function"
  stats::median(x)
}

# Nor is it the same name as the global one.
#| median : (x:{dbl}) -> dbl1
ns_global <- function(x) median(x)
ns_global_ns <- function(x) stats::median(x)

# A namespaced function can be passed around like any other.
ns_first_class <- function() {
  f <- stats::median
  f(1)
}

# The arguments are checked against the declared signatures.
ns_err <- function() stats::median(list(1))

# A name with no declared signature is unbound.
ns_unknown <- function(x) stats::sd(x)

# ========== Search path ==========

# The functions of R are declared in their namespace (cf. 00_defs.r). An
# unqualified name that no definition binds is looked up in R's search path,
# which ends with `base`.
#| base::nchar : (x:CHR) -> int
ns_search <- function() nchar("abc")
ns_search_qualified <- function() base::nchar("abc")

# Declaring another signature of a function of 00_defs.r overloads it.
#| base::xor : (x:tt, y:ff) -> tt
ns_overload <- function() xor(TRUE, FALSE)

# A global definition hides the base function, which `base::` still reaches.
xor <- function(x, y) "redefined"
ns_hidden <- function() xor(TRUE, FALSE)
ns_unhidden <- function() base::xor(TRUE, FALSE)

# A call skips the global names that are not functions, as R does.
typeof <- "not a function"
ns_skip <- function() typeof(1)
ns_no_skip <- function() typeof

# A class-overload can extend a generic of the search path.
#| new print.ns_rec
#| print.ns_rec : (x:any) -> CHR1
ns_print <- function(x) print(x)
