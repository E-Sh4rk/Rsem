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
