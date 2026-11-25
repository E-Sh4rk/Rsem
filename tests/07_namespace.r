# ========== Namespaces ==========

# The methods and class-overloads used below (cf. 04_s3.r). A method is
# associated with its namespace (the global one if it has none). The
# namespace of a class-overload, as in `base::print.ns_df`, is written before the
# generic: the latter is the method of this namespace, or else of the search path
# (for `new print @ ns_rec`, `base::print`, as there is no global one).
#| method base::print
#| method shapes::area
#| new print @ ns_rec
#| new base::print @ ns_df
#| new shapes::area @ ns_square

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
#| print.ns_rec : (x:any) -> CHR1
ns_print <- function(x) print(x)
# The parameter of `ns_print` has an unknown class: inferring its type only
# considers the fallback signature of `print` (cf. `MetaEnv.sigs`). The
# method applies to a value of known class.
#| ns_rec_new : () -> dbl1<ns_rec>
ns_print_rec <- print(ns_rec_new())

# A class-overload can also be declared in a namespace, as the methods of R's
# packages are (e.g. `base::print.data.frame`). It extends the generic of the
# search path, and is reachable through its namespace.
#| base::print.ns_df : (x:any) -> LGL1
ns_method <- function(x) print(x)
ns_method_direct <- function(x) base::print.ns_df(x)
#| ns_df_new : () -> dbl1<ns_df>
ns_method_df <- print(ns_df_new())

# The generic of a namespaced method is first looked up in its own namespace:
# here `shapes::area`, and not the global `area` of 04_s3.r.
#| shapes::area : (shape:dbl1) -> dbl1
#| shapes::area.ns_square : (shape:dbl1) -> CHR1
ns_area <- function(s) shapes::area(s)
ns_area_global <- function(s) area(s)
#| ns_square_new : () -> dbl1<ns_square>
ns_area_square <- shapes::area(ns_square_new())

# Two methods with the same name do not affect each other: neither the
# class-overloads, nor the return type of `pa::ns_gen` apply to `pb::ns_gen`. A
# global function with the name of a method is not a method.
#| method pa::ns_gen : CHR
#| method pb::ns_gen
#| new pa::ns_gen @ ns_a
#| new pb::ns_gen @ ns_b
#| ns_a_new : () -> dbl1<ns_a>
#| ns_b_new : () -> dbl1<ns_b>
#| pa::ns_gen.ns_a : (x:any) -> CHR1
#| pb::ns_gen.ns_b : (x:any) -> LGL1
ns_gen_a <- pa::ns_gen(ns_a_new())
ns_gen_b <- pb::ns_gen(ns_b_new())
ns_gen_first_class <- pb::ns_gen
ns_gen <- function(x) x
ns_gen_global <- ns_gen(ns_a_new())

# ========== Methods of an inferred generic ==========

# The type inferred for a generic (cf. 04_s3.r) is kept as a base signature when
# the signature of a class-overload or of its default method is added to it: the
# latter makes it more precise (`inf_default`), but not applicable to fewer values.
#| inferred1.square : (x: any) -> CHR1
#| inferred2.square : (x: any) -> CHR1
#| inferred2.default : (x: dbl) -> lgl1
inf_kept <- inferred1("a")
inf_square <- inferred1(sq_new())
inf_default <- inferred2(0)
inf_other <- inferred2("a")
inf_infer <- function(x) inferred2(x)
