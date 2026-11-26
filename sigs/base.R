# Signatures of the functions of R's `base` package.
#
# They are declared in the `base` namespace, which is where an unqualified name
# is looked up when no definition of the program binds it (cf. R's search
# path). A program can thus redefine `paste` without affecting `base::paste`;
# overloading the base function itself is done by declaring another signature
# of `base::paste`.
#
# Conventions:
# - A function returning a value that never carries a class (or only one that
#   does not matter, such as the class R gives to a `ts`) says so with `<>`.
#   One whose result keeps the classes of its arguments (arithmetic, the
#   `Math` group, the replacements, ...) says so with a class row variable,
#   e.g. `dbl1<`c> -> dbl1<`c>`. The classes whose methods behave otherwise
#   overload them (cf. "Class-overloads"). Results of unknown class should be
#   avoided: a value of unknown class may have any of the classes that
#   overload a generic, so applying the generic to it has to consider all of
#   its methods.
# - The overloads of a function are intersected, so that the result of a call
#   is the intersection of the results of all the overloads that accept its
#   arguments. Overloads with overlapping domains must thus have compatible
#   results: a scalar overload typically returns the scalar version of the
#   vector one.
# - When the argument of a call still contains inference variables, Rsem tries
#   each overload alone rather than their intersection (cf. `amask` in
#   lang/transform.ml). Overloads that only cover the possible arguments
#   together (e.g. `int -> INT` and `DBL -> DBL`) then fail: one of them must
#   cover them alone, which is why arithmetic uses `v('a)&dbl`.
# - An elementwise function is length-preserving, which the algebra cannot say:
#   it gets one overload for scalars, and one for vectors of any length.
# - An overload can be an intersection of arrows, written with `&&`, one per
#   line: an annotation continues on the next `#|` lines that start with more
#   than one blank. In inference mode, it is tried as a whole, as one
#   alternative, so the arrows of an overload are grouped to make inference
#   faster:
#   - overloads whose domains overlap pairwise (e.g. the vector and the scalar
#     versions of an arithmetic operator) are grouped into one. Its arrows
#     share their type variables (in particular the class row variable `c):
#     an overload of the group no longer needs its own, the other ones
#     constraining the result as well;
#   - overloads with disjoint domains (e.g. a unary and a binary operator, or
#     `typeof` for each type) stay separate: grouped, every application to an
#     argument of unknown type would have to consider all of their arrows at
#     once, which makes inference much slower (for `typeof`, from a fraction
#     of a second to more than a minute). Nor are two of them grouped through
#     a third one that overlaps both (e.g. the `any` overload of `typeof`):
#     the overloads of a group overlap pairwise.
#   - an overload with label variables (e.g. `#k`) is never grouped with other
#     ones: it would make the whole group symbolic.

# ========== Methods ==========

# The generics that dispatch on the class of their first argument. Only those
# declared here can have class-overloads. They are the ones of their namespace:
# `method g` declares the global `g`, not `base::g`. Their other signatures do
# not apply to a first argument whose class has a method (e.g.
# `<@as.character, ...>`): a fallback signature covers it, whose result is the
# return type declared for the method (e.g. `CHR` for
# `method base::as.character : CHR`), which its class-overloads must comply with,
# i.e. they must return a subtype of it. If none is declared, it is the union of
# the results of the class-overloads (`empty` if there is none). A method is thus
# declared even when no class-overload of it is. A signature of the default
# method of a method (e.g. `as.character.default`) is also added to the other
# signatures of the method, except for the operators of the `Ops` group generic,
# which have none. When the type of the arguments must be inferred, it is only
# considered if the first one certainly has no class-overload: a signature that
# inference must always consider is declared for the method itself.
#| method base::(+)
#| method base::(-)
#| method base::(*)
#| method base::(/)
#| method base::([])
#| method base::([[]])
#| method base::as.character : CHR

# The other S3 generics of R's attached packages (R 4.6): those R dispatches on
# the class of their first argument, whether a class-overload is declared for
# them or not (one can be declared later, by r-typeshed or for the package
# being typed). A generic is declared with the return type R's conventions give
# its methods, when there is one (a conversion returns its type, a predicate
# logicals, `length` a count, `format` strings), and none otherwise. The group
# generics themselves (`Ops`, `Math`, `Summary`, `Complex`) are not: their
# members are.
# The members of the group generics `Ops`, `Math`, `Summary` and `Complex`:
#| method base::abs
#| method base::acos
#| method base::acosh
#| method base::all : LGL1
#| method base::any : LGL1
#| method base::Arg
#| method base::asin
#| method base::asinh
#| method base::atan
#| method base::atanh
#| method base::ceiling
#| method base::Conj
#| method base::cos
#| method base::cosh
#| method base::cospi
#| method base::cummax
#| method base::cummin
#| method base::cumprod
#| method base::cumsum
#| method base::digamma
#| method base::exp
#| method base::expm1
#| method base::floor
#| method base::gamma
#| method base::Im
#| method base::lgamma
#| method base::log
#| method base::log10
#| method base::log1p
#| method base::log2
#| method base::max
#| method base::min
#| method base::Mod
#| method base::prod
#| method base::range
#| method base::Re
#| method base::sign
#| method base::sin
#| method base::sinh
#| method base::sinpi
#| method base::sqrt
#| method base::sum
#| method base::tan
#| method base::tanh
#| method base::tanpi
#| method base::trigamma
#| method base::trunc
# The internal generics (primitives and `.Internal` functions that dispatch):
#| method base::(!)
#| method base::(!=) : LGL
#| method base::([[]]<-)
#| method base::([]<-)
#| method base::(@)
#| method base::(@<-)
#| method base::(&)
#| method base::(%*%)
#| method base::(%/%)
#| method base::(%%)
#| method base::(^)
#| method base::(<) : LGL
#| method base::(<=) : LGL
#| method base::(==) : LGL
#| method base::(>) : LGL
#| method base::(>=) : LGL
#| method base::(|)
#| method base::($)
#| method base::($<-)
#| method base::anyNA : LGL1
#| method base::as.call : lang
#| method base::as.complex : CLX
#| method base::as.double : DBL
#| method base::as.environment : env
#| method base::as.integer : INT
#| method base::as.logical : LGL
#| method base::as.numeric : DBL
#| method base::as.raw : RAW
#| method base::as.vector
#| method base::c
#| method base::cbind
#| method base::dim : INT | DBL | null
#| method base::dim<-
#| method base::dimnames : list | null
#| method base::dimnames<-
#| method base::is.array : LGL1
#| method base::is.finite : LGL
#| method base::is.infinite : LGL
#| method base::is.matrix : LGL1
#| method base::is.na : LGL
#| method base::is.nan : LGL
#| method base::is.numeric : LGL1
#| method base::is.unsorted : LGL1
#| method base::length : INT1 | DBL1
#| method base::length<-
#| method base::lengths
#| method base::levels<-
#| method base::names : CHR | null
#| method base::names<-
#| method base::nchar : INT
#| method base::rbind
#| method base::rep
#| method base::rep_len
#| method base::rep.int
#| method base::round
#| method base::seq.int
#| method base::signif
#| method base::unlist
#| method base::xtfrm
# The generics written in R (with `UseMethod`):
#| method base::all.equal : LGL1 | CHR
#| method base::anyDuplicated : INT1 | DBL1
#| method base::aperm
#| method base::as.array
#| method base::as.Date : DBL<Date, ...>
#| method base::as.expression
#| method base::as.function : (...: any) -> any
#| method base::as.list : list
#| method base::as.matrix
#| method base::as.null
#| method base::as.POSIXct : DBL<POSIXct, POSIXt, ...>
#| method base::as.POSIXlt : { any }<POSIXlt, POSIXt, ...>
#| method base::as.single
#| method base::as.table
#| method base::by
#| method base::chol
#| method base::chooseOpsMethod
#| method base::close
#| method base::conditionCall
#| method base::conditionMessage : CHR
#| method base::cut
#| method base::determinant
#| method base::diff
#| method base::droplevels
#| method base::duplicated : LGL
#| method base::flush
#| method base::format : CHR
#| method base::getDLLRegisteredRoutines
#| method base::is.na<-
#| method base::isSymmetric : LGL1
#| method base::julian : DBL
#| method base::kappa
#| method base::labels
#| method base::levels : CHR | null
#| method base::mean
#| method base::merge
#| method base::months : CHR
#| method base::mtfrm
#| method base::nameOfClass
#| method base::open
#| method base::plot
#| method base::pretty
#| method base::print
#| method base::qr
#| method base::quarters : CHR
#| method base::rev
#| method base::row.names
#| method base::row.names<-
#| method base::rowsum
#| method base::scale
#| method base::seek
#| method base::seq
#| method base::sequence
#| method base::solve
#| method base::sort_by
#| method base::split
#| method base::split<-
#| method base::subset
#| method base::summary
#| method base::t
#| method base::toString : CHR1
#| method base::transform
#| method base::truncate
#| method base::unique
#| method base::units
#| method base::units<-
#| method base::weekdays : CHR
#| method base::with
#| method base::within
# Those of `graphics` and `grDevices`:
#| method graphics::barplot
#| method graphics::boxplot
#| method graphics::cdplot
#| method graphics::contour
#| method graphics::hist
#| method graphics::identify
#| method graphics::image
#| method graphics::lines
#| method graphics::mosaicplot
#| method graphics::pairs
#| method graphics::persp
#| method graphics::points
#| method graphics::spineplot
#| method graphics::stripchart
#| method graphics::sunflowerplot
#| method graphics::text
#| method grDevices::as.raster
#| method grDevices::glyphJust

# ========== Class-overloads ==========

# The S3 methods `base` defines for its own classes. They are declared before
# any other annotation, as they define the class hierarchy (each class
# implements the method classes of its generics, e.g. `Date` implements
# `@"+"`) that types are built with. Their signatures are in the "S3 methods" section.
#
# A class-overload of a generic takes precedence over its other signatures:
# they no longer apply to a first argument of that class. R dispatches the
# operators on both operands (`1 + d` calls `+.Date` too), but only the first
# one is taken into account here: `1 + d` keeps the type the default
# signatures give it, which does not say that the result is a `Date`.
#
# R defines the arithmetic of `factor` and `difftime` as methods of the `Ops`
# group generic, which stands for each operator: they are declared per
# operator. The comparisons are not overloaded, the default signatures giving
# the right type.
#| new base::(+) @ Date
#| new base::(-) @ Date
#| new base::([]) @ Date
#| new base::([[]]) @ Date
#| new base::(+) @ POSIXt
#| new base::(-) @ POSIXt
#| new base::([]) @ POSIXct
#| new base::([[]]) @ POSIXct
#| new base::(+) @ difftime
#| new base::(-) @ difftime
#| new base::(*) @ difftime
#| new base::(/) @ difftime
#| new base::([]) @ difftime
#| new base::(+) @ factor
#| new base::(-) @ factor
#| new base::(*) @ factor
#| new base::(/) @ factor
#| new base::([]) @ factor
#| new base::([[]]) @ factor


# ========== Arithmetic ==========

# The mode of the result is the one of the operands (which tallying unifies),
# and its length is the one of the longest operand. Logical operands are the
# exception: they give an integer (`TRUE + TRUE` is `2L`).
# Overloads per mode (e.g. `int -> INT` and `DBL -> DBL`) would say so, but
# none of them covers a `v('a)&dbl` argument alone, which Rsem needs when the
# argument still contains inference variables (see above). So the vector
# overload covers every operand, with the integer result of logicals added to
# the mode of the others (`dbl\lgl`, double and integer: lowercase `lgl` is
# also raw). The `DBL1` overloads restore the double of scalar arithmetic with
# a double operand. The same for vectors (`DBL`) would make the result of
# double vectors exact too, but costs as much inference time as a second
# vector overload per mode: arithmetic in loops got 1.6x slower.
# The result keeps the classes of the operands (those of `e1` if it has some,
# and those of `e2` otherwise): both share a class row variable, which a row
# can instantiate with a union, e.g. `x + 1` has the classes of `x` or none.
# `NULL` is an empty vector: with a binary operator, it gives an empty vector
# (`NULL - 1` is `numeric(0)`), in the vector overload, which adds no
# overload. Unary `-NULL` is an error.
#| base::(-) : ( e1:(v('a)&dbl)<`c> ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|          && ( e1:dbl1<`c> ) -> dbl1<`c>
#|          && ( e1:DBL1<`c> ) -> DBL1<`c>
#| base::(-) : ( e1:(v('a)&dbl)<`c> | null, e2:(v('a)&dbl)<`c> | null ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|          && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> dbl1<`c>
#|          && ( e1:DBL1<`c>, e2:dbl1<`c> ) -> DBL1<`c>
#|          && ( e1:dbl1<`c>, e2:DBL1<`c> ) -> DBL1<`c>

#| base::(+) : ( e1:(v('a)&dbl)<`c> ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|          && ( e1:dbl1<`c> ) -> dbl1<`c>
#|          && ( e1:DBL1<`c> ) -> DBL1<`c>
#| base::(+) : ( e1:(v('a)&dbl)<`c> | null, e2:(v('a)&dbl)<`c> | null ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|          && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> dbl1<`c>
#|          && ( e1:DBL1<`c>, e2:dbl1<`c> ) -> DBL1<`c>
#|          && ( e1:dbl1<`c>, e2:DBL1<`c> ) -> DBL1<`c>

#| base::(*) : ( e1:(v('a)&dbl)<`c> | null, e2:(v('a)&dbl)<`c> | null ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|          && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> dbl1<`c>
#|          && ( e1:DBL1<`c>, e2:dbl1<`c> ) -> DBL1<`c>
#|          && ( e1:dbl1<`c>, e2:DBL1<`c> ) -> DBL1<`c>
#| base::(%%) : ( e1:(v('a)&dbl)<`c> | null, e2:(v('a)&dbl)<`c> | null ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|           && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> dbl1<`c>
#|           && ( e1:DBL1<`c>, e2:dbl1<`c> ) -> DBL1<`c>
#|           && ( e1:dbl1<`c>, e2:DBL1<`c> ) -> DBL1<`c>
#| base::(%/%) : ( e1:(v('a)&dbl)<`c> | null, e2:(v('a)&dbl)<`c> | null ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|            && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> dbl1<`c>
#|            && ( e1:DBL1<`c>, e2:dbl1<`c> ) -> DBL1<`c>
#|            && ( e1:dbl1<`c>, e2:DBL1<`c> ) -> DBL1<`c>

# Always a double, even for integer operands (`1L / 2L` is `0.5`).
#| base::(/) : ( e1:dbl<`c> | null, e2:dbl<`c> | null ) -> DBL<`c>
#|          && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> DBL1<`c>
#| base::(^) : ( e1:dbl<`c> | null, e2:dbl<`c> | null ) -> DBL<`c>
#|          && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> DBL1<`c>

# ========== Comparisons and Boolean operators ==========

# Contrarily to arithmetic, comparisons and Boolean operators do not keep the
# class of their operands. `NULL` is an empty vector: comparing it gives
# `logical(0)`.
#| base::(<) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#|          && ( e1:vec|null, e2:vec|null ) -> LGL<>
#| base::(<=) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#|           && ( e1:vec|null, e2:vec|null ) -> LGL<>
#| base::(>) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#|          && ( e1:vec|null, e2:vec|null ) -> LGL<>
#| base::(>=) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#|           && ( e1:vec|null, e2:vec|null ) -> LGL<>
#| base::(==) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#|           && ( e1:vec|null, e2:vec|null ) -> LGL<>
#| base::(!=) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#|           && ( e1:vec|null, e2:vec|null ) -> LGL<>

# `&&` and `||` have no signature: being short-circuiting, they are not typed
# as applications but encoded as conditionals (cf. `encode_short_circuit` in
# lang/transform.ml): `x && y` is `if (x) y else FALSE`, and `x || y` is
# `if (x) TRUE else y`.

# `!`, `&`, `|` and `xor` also take numbers (`!0` is `TRUE`), and are bitwise
# on raw vectors, hence a result of type `lgl` rather than `LGL`.
#| base::(!) : ( x:tt ) -> ff<>
#|          && ( x:dbl1 ) -> lgl1<>
#|          && ( x:dbl ) -> lgl<>
#| base::(!) : ( x:ff ) -> tt<>

#| base::(&) : ( e1:dbl1, e2:dbl1 ) -> lgl1<>
#|          && ( e1:dbl, e2:dbl ) -> lgl<>
#| base::(|) : ( e1:dbl1, e2:dbl1 ) -> lgl1<>
#|          && ( e1:dbl, e2:dbl ) -> lgl<>
#| base::xor : ( x:dbl1, y:dbl1 ) -> lgl1<>
#|          && ( x:dbl, y:dbl ) -> lgl<>

# ========== Lookups ==========

#| base::($) : (x:{ #k:'a, any}, k: #k) -> 'a
#| base::($<-) : (x:{ #k:any?, `r}<`c>, k: #k, v:'b) -> { #k:'b, `r}<`c>
# The bindings of an environment (`e$x`, `e$x <- v`, e.g. R6 objects), of
# which the type says nothing: without label variables, so that inference
# stays cheap. Not for lists whose type says nothing of the element (a data
# frame read from a file): an overload `(x:list, k:chr1) -> dyn` also
# applies to the lists that have it, and its `dyn` replaces their precise
# result (`list(a = 1)$a + 1` was no longer `DBL1`).
#| base::($) : (x:env, k:chr1) -> dyn
#| base::($<-) : (x:env, k:chr1, v:any) -> env
# Not declared (yet): `$` and `[[` of an environment (`e$x`, `e[["x"]]`), and
# `$` of an element a list does not have, or of `NULL` (both `NULL` in R). As
# separate overloads, each would add a case to the type of every definition
# that projects a parameter (`x$k` on an unknown `x` would also be typed for
# `x` an environment, or a list without `k`), and the absent element made
# inference slower: on the dashboard's packages, it typed about 6 more
# definitions, had 10 more timeouts and changed 183 signatures.

# The default subsets drop the class (the classes whose methods keep it
# overload them, cf. "S3 methods"), and so does `[[` of an atomic vector. A
# replacement keeps the attributes of `x`, its class among them.
#| base::([]) : (x:v('a), ...: dbl|CHR) -> v('a)<>
#| base::([]) : (x:{'a}, ...: dbl|CHR) -> {'a}<>
#| base::([]<-) : (x:v('a)<`c>, ...: dbl|CHR, v:v('a)) -> v('a)<`c>
#| base::([]<-) : (x:{'a}<`c>, ...: dbl|CHR, v:{'a}) -> {'a}<`c>
# `[` without method dispatch.
#| base::.subset : (x:v('a), ...: dbl|CHR) -> v('a)<>
#| base::.subset : (x:{'a}, ...: dbl|CHR) -> {'a}<>

#| base::([[]]) : (x:v('a), ...: dbl|CHR) -> v1('a)<>
#| base::([[]]) : (x:{'a}, ...: dbl) -> 'a
#| base::([[]]) : (x:{'a}, ...: CHR) -> 'a|null
#| base::([[]]) : (x:{ #k:'a, any }, k: #k) -> 'a
#| base::([[]]<-) : (x:v('a)<`c>, ...: dbl|CHR, v:v('a)) -> v('a)<`c>
#| base::([[]]<-) : (x:{'a}<`c>, ...: chr, v:'a) -> {'a}<`c>
#| base::([[]]<-) : (x:{ #k:any?, `r}<`c>, k: #k, v:'b) -> { #k:'b, `r}<`c>

# `[[` without method dispatch.
#| base::.subset2 : (x:v('a), ...: dbl|CHR) -> v1('a)
#| base::.subset2 : (x:{'a}, ...: dbl) -> 'a
#| base::.subset2 : (x:{'a}, ...: CHR) -> 'a|null
#| base::.subset2 : (x:{ #k:'a, any }, k: #k) -> 'a

# ========== Classes and attributes ==========

#| base::class : (x:any) -> CHR<>
# A class given as a literal string is the class of the result (the label
# variable `#c` stands for it); otherwise the classes are unknown.
#| base::class<- : (x:'a<...>, v:#c) -> 'a<#c>
#| base::class<- : (x:'a<...>, v:chr) -> 'a<...>
#| base::class<- : (x:'a<...>, v:null) -> 'a<>
#| base::unclass : (x:'a<...>) -> 'a<>
# The class attribute only: `NULL` for a value without one, where `class`
# gives the implicit class.
#| base::oldClass : (x:<>) -> null
#| base::oldClass : (x:~<>) -> CHR<>
# Sets the class attribute, as `class<-` does.
#| base::oldClass<- : (x:'a<...>, v:#c) -> 'a<#c>
#| base::oldClass<- : (x:'a<...>, v:chr) -> 'a<...>
#| base::oldClass<- : (x:'a<...>, v:null) -> 'a<>
# Whether `x` has a class (of its class attribute: the implicit classes, such
# as `integer` or `matrix`, are not tracked). With a literal `what` (the label
# variable `#c` stands for it), the type of `x` decides the result, so that the
# test narrows it (e.g. `if (inherits(r, "try-error"))` after `try`). A `what`
# that is not a literal leaves `#c` unresolved: these overloads then do not
# apply, and cost nothing.
#| base::inherits : (x:any, what:CHR, which:ff?) -> LGL1<>
#| base::inherits : (x:any, what:CHR, which:tt) -> INT<>
#| base::inherits : (x:<#c, ...>, what:#c, which:ff?) -> tt<>
#| base::inherits : (x:<~#c, ...>, what:#c, which:ff?) -> ff<>
#| base::names : (x:any) -> CHR<> | null
#| base::names<- : (x:'a, v:chr|null) -> 'a
#| base::rownames<- : (x:'a, v:vec|null) -> 'a
#| base::colnames<- : (x:'a, v:vec|null) -> 'a

# The attribute is selected by a literal name, so the label is polymorphic.
#| base::attr : (x:any with { #k:'b, any }, which: #k, exact:lgl1?) -> 'b
# Not declared: an attribute that may be missing (`NULL` when it is), as
# `(x:any with { #k:'b?, any }, which: #k, ...) -> 'b | null`. A second
# overload with a label variable makes rematch (`attr` of `regexpr` results)
# run out of memory: more than 16 GB after 6 minutes, against 120 MB in 18 s.
# An environment's attributes (e.g. the `name` of a package's), of which the
# type says nothing.
#| base::attr : (x:env, which:CHR1, exact:lgl1?) -> dyn
# Setting an attribute to `NULL` removes it.
#| base::attr<- : (x:'a<`c> with { #k:any?, `r }, which: #k, v:~null & 'b) -> 'a<`c> with { #k:'b, `r }
#| base::attr<- : (x:'a<`c> with { #k:any?, `r }, which: #k, v:null) -> 'a<`c> with { #k:absent, `r }

# The attributes of `x` as a list, the row variable `r carrying them over
# exactly: NULL when there are none, and the class (which is not part of the
# `with` record) as an extra `class` entry. The three cases do not overlap:
# their results would otherwise be intersected (`null` with `{ }` is empty).
#| base::attributes : (x:<> with { }) -> null
#|                  && (x:(<> with { `r }) & ~(<> with { })) -> { `r }<>
#|                  && (x:(any with { `r }) & ~<>) -> { class: CHR, `r }<>

# The attributes it sets are not tracked: the result has the type of `.Data`
# with any attributes. Its class, when given as a literal string, is.
#| base::structure : (.Data:v('a), class:#c, ...: any) -> v('a)<#c>
#| base::structure : (.Data:{'a}, class:#c, ...: any) -> {'a}<#c>
#| base::structure : (.Data:v('a), ...: any) -> v('a)
#|                && (.Data:any, ...: any) -> any
#| base::structure : (.Data:{'a}, ...: any) -> {'a}
# The same for `attributes<-`, which sets them all (the class among them), or
# removes them all with `NULL`.
#| base::attributes<- : (x:v('a), v:{ any }) -> v('a)
#| base::attributes<- : (x:{'a}, v:{ any }) -> {'a}
#| base::attributes<- : (x:v('a), v:null) -> v('a)<>
#| base::attributes<- : (x:{'a}, v:null) -> {'a}<>

# Like `dim`: the `dimnames` attribute when the type says whether it is there,
# and a list of names (or `NULL` for a dimension without names) otherwise.
#| base::dimnames : (x:any with { dimnames: 'd, any }) -> 'd
#|               && (x:any with { dimnames: absent, any }) -> null
#|               && (x:any) -> { CHR<> | null }<> | null
# Setting the dimnames to `NULL` removes them. On a data frame (a method), they
# set the row names and the names instead.
#| base::dimnames<- : (x:'a<`c> with { dimnames: any?, `r }, v:list & 'b) -> 'a<`c> with { dimnames: 'b, `r }
#| base::dimnames<- : (x:'a<`c> with { dimnames: any?, `r }, v:null) -> 'a<`c> with { dimnames: absent, `r }

# Sets the attributes of `x` from the list `v`, but keeps those of its own
# that are incompatible (dim, names): as `attributes<-`.
#| base::mostattributes<- : (x:v('a), v:{ any }) -> v('a)
#| base::mostattributes<- : (x:{'a}, v:{ any }) -> {'a}
# `x` without its names and dimnames.
#| base::unname : (obj:v('a), force:lgl1?) -> v('a)
#| base::unname : (obj:{'a}, force:lgl1?) -> {'a}
#| base::unname : (obj:null, force:lgl1?) -> null
# Converts `x` to another storage mode, keeping its attributes. Not with a
# class row variable: on a classed `x` (vctrs' vec_cast.difftime.difftime),
# inference went from 6 s to over 30 s.
#| base::storage.mode<- : (x:vec<>, v:CHR1) -> vec<>
#|                      && (x:vec, v:CHR1) -> vec

# ========== Types and predicates ==========

#| base::typeof : ( x: DBL ) -> "double"<>
#|             && ( x: any ) -> CHR1<>
#| base::typeof : ( x: CHR ) -> "character"<>
#| base::typeof : ( x: LGL ) -> "logical"<>
#| base::typeof : ( x: INT ) -> "integer"<>
#| base::typeof : ( x: CLX ) -> "complex"<>
#| base::typeof : ( x: RAW ) -> "raw"<>
#| base::typeof : ( x: list ) -> "list"<>
#| base::typeof : ( x: null ) -> "NULL"<>

#| base::is.null : (x:null) -> tt<>
#| base::is.null : (x:~null) -> ff<>
#| base::is.na : (x:vec1) -> LGL1<>
#|            && (x:any) -> LGL<>
# Whether an element is `NA` (with `recursive = TRUE`, in the elements of the
# lists too).
#| base::anyNA : (x:any, recursive:lgl1?) -> LGL1<>
#| base::is.character : (x:CHR) -> tt<>
#| base::is.character : (x:~CHR) -> ff<>
# A factor is not an integer vector for `is.integer`.
#| base::is.integer : (x:INT<~factor, ...>) -> tt<>
#| base::is.integer : (x:~INT<~factor, ...>) -> ff<>
#| base::is.unsorted : (x:any, na.rm:lgl1?, strictly:lgl1?) -> LGL1<>
#| base::is.double : (x:DBL) -> tt<>
#| base::is.double : (x:~DBL) -> ff<>
# Like `dim`: whether the `dim` attribute is there, when the type says so.
#| base::is.array : (x:any with { dim: any, any }) -> tt<>
#|               && (x:any with { dim: absent, any }) -> ff<>
#|               && (x:any) -> LGL1<>
#| base::isNamespace : (ns:any) -> LGL1<>
# Factors and the date and time classes are built on numbers, but are not
# numeric for `is.numeric`: any other class keeps it `TRUE`.
#| base::is.numeric : (x:(DBL|INT)<~factor, ~Date, ~POSIXt, ~difftime, ...>) -> tt<>
#|                 && (x:DBL|INT) -> LGL1<>
#| base::is.numeric : (x:~(DBL|INT)) -> ff<>
#| base::is.atomic : (x:vec) -> tt<>
#| base::is.atomic : (x:~vec) -> ff<>
# Whether `x` has a class attribute.
#| base::is.object : (x:<>) -> ff<>
#| base::is.object : (x:~<>) -> tt<>
#| base::is.data.frame : (x:<data.frame, ...>) -> tt<>
#|                    && (x:<~data.frame, ...>) -> ff<>
#| base::is.list : (x:list) -> tt<>
#|              && (x:any) -> LGL1<>
#| base::is.environment : (x:env) -> tt<>
#| base::is.environment : (x:~env) -> ff<>
#| base::is.function : (x:(empty -> any)) -> tt<>
#| base::is.function : (x:~(empty -> any)) -> ff<>
#| base::is.factor : (x:any) -> LGL1<>
#| base::is.matrix : (x:any) -> LGL1<>
#| base::is.nan : (x:vec1) -> LGL1<>
#|             && (x:any) -> LGL<>
#| base::is.logical : (x:LGL) -> tt<>
#| base::is.logical : (x:~LGL) -> ff<>
#| base::is.finite : (x:vec1) -> LGL1<>
#|                && (x:any) -> LGL<>
#| base::is.infinite : (x:vec1) -> LGL1<>
#|                  && (x:any) -> LGL<>
#| base::isTRUE : (x:~lgl) -> ff<>
#|             && (x:any) -> LGL1<>
#| base::isFALSE : (x:~lgl) -> ff<>
#|              && (x:any) -> LGL1<>
#| base::identical : (x:any, y:any, ...: any) -> LGL1<>
#| base::(%in%) : (x:vec1, table:vec|null) -> LGL1<>
#|             && (x:vec|null, table:vec|null) -> LGL<>
# Like `!`, they coerce numbers. `NULL` is an empty vector (`any(NULL)` is
# `FALSE`).
#| base::all : (...: dbl|null, na.rm:lgl1?) -> LGL1<>
#| base::any : (...: dbl|null, na.rm:lgl1?) -> LGL1<>

#| base::is.raw : (x:RAW) -> tt<>
#| base::is.raw : (x:~RAW) -> ff<>
#| base::is.ordered : (x:any) -> LGL1<>

# ========== Vectors and lists ==========

# The named elements are matched by name only, hence after `...`: before it,
# they would also take positional arguments, `list(1, ok = TRUE)$ok` being `1`.
#| base::list : (...: 'a, ( #l_i : 'a_i )_i ) -> { ( #l_i : 'a_i )_i, 'a }<>

# `c()` of nothing but `NULL`s (or of nothing at all) is `NULL`. The overloads
# that exclude it need a first argument `x`: it is not in R's signature of `c`,
# but matches the same calls. `c` dispatches on its first argument: its methods
# (for factors, dates, ...) keep the class, so the result is given the classes
# of `x` (which the default method in fact drops, but then `x` has typically
# none). This takes a single overload: a third one on vectors makes inference
# blow up in memory (e.g. on rematch::re_match_all1 with --gradual).
# After a list, atomic vectors give their elements to the result:
# `c(list(), all = FALSE)` is `list(all = FALSE)`. A vector followed by a list
# gives a list too, but an overload for it would also match the calls of
# vectors only.
#| base::c : ( x:v('p)<`c>, ...: v('p)|null ) -> v('p)<`c>
#|        && ( ...: v('p)|null ) -> v('p) | null
#| base::c : ( x:{'a}, ...: {'a}|v('p)|null ) -> {'a | v1('p)<>}<>
#|        && ( ...: {'a}|null ) -> {'a}<> | null

#| base::length : (x:any) -> INT1<>
#| base::rev : (x:v('a)) -> v('a)
#| base::rev : (x:{'a}) -> {'a}
#| base::rev : (x:null) -> null
# `values` inserted after the `after` first elements of `x` (at its end by
# default).
#| base::append : (x:v('a)|null, values:v('a)|null, after:dbl1?) -> v('a)<>
#| base::append : (x:{'a}, values:{'a}|v('p)|null, after:dbl1?) -> {'a | v1('p)<>}<>
#| base::seq_along : (along.with:any) -> INT<>
# The length of each element (named after them).
#| base::lengths : (x:any, use.names:lgl1?) -> INT<>
# The positions of the elements of `x` in `table` (`nomatch`, `NA` by default,
# for the missing ones).
#| base::match : (x:vec1, table:vec|null, nomatch:vec1?, incomparables:any?, ...: any) -> INT1<>
#|            && (x:vec|null, table:vec|null, nomatch:vec1?, incomparables:any?, ...: any) -> INT<>
# Partial matching: the position of the element of `table` that `x` is a
# prefix of.
#| base::pmatch : (x:vec1, table:vec|null, nomatch:vec1?, duplicates.ok:lgl1?) -> INT1<>
#|             && (x:vec|null, table:vec|null, nomatch:vec1?, duplicates.ok:lgl1?) -> INT<>
#| base::duplicated : (x:vec|list|null, incomparables:any?, ...: any) -> LGL<>
# The position of the first duplicate, 0 when there is none.
#| base::anyDuplicated : (x:vec|list|null, incomparables:any?, ...: any) -> INT1<>
# `sort` and `order` are generic; `sort` keeps the class (e.g. of factors).
#| base::sort : (x:v('a)<`c>, decreasing:lgl1?, ...: any) -> v('a)<`c>
#| base::sort : (x:null, decreasing:lgl1?, ...: any) -> null
#| base::order : (...: any, na.last:lgl1|null?, decreasing:lgl?, method:CHR1?) -> INT<>
# The ranks of the elements: doubles with ties averaged (the default),
# integers with the other `ties.method`s.
#| base::rank : (x:dbl1|chr1, na.last:any?, ties.method:CHR1?) -> (DBL1|INT1)<>
#|           && (x:dbl|chr, na.last:any?, ties.method:CHR1?) -> (DBL|INT)<>
# The elements of `x` for which `f` is true.
#| base::Filter : (f:any, x:v('a)) -> v('a)
#| base::Filter : (f:any, x:{'a}) -> {'a}
# `unique` is generic: the default method restores the class of factors and
# of the date and time classes, and drops the other attributes. A value of
# another type may have a class with a method: its result is unknown.
#| base::unique : (x:v('a)<`c>, incomparables:any?, ...: any) -> v('a)<`c>
#|             && (x:any, incomparables:any?, ...: any) -> any
#| base::unique : (x:{'a}<`c>, incomparables:any?, ...: any) -> {'a}<`c>
#| base::unique : (x:null, incomparables:any?, ...: any) -> null
# The default method drops the class.
#| base::unique.default : (x:v('a), incomparables:any?, ...: any) -> v('a)<>
#|                     && (x:{'a}, incomparables:any?, ...: any) -> {'a}<>
#|                     && (x:null, incomparables:any?, ...: any) -> null
#| base::seq_len : (length.out:dbl1) -> INT<>
# The number of rows (columns) of a matrix or a data frame, and the length
# (1) of a vector.
#| base::NROW : (x:any) -> INT1<>
#| base::NCOL : (x:any) -> INT1<>
# `seq` is generic: its methods (for dates, ...) keep the class. A single
# `from` of length other than 1 is `seq_along(from)`. `to` and `by` must have
# length 1, but are vectors here: `x[1L]`, their usual source, is not a scalar
# for the algebra.
#| base::seq : (from:dbl?, to:dbl?, by:dbl?, length.out:dbl1?, along.with:any?, ...: any) -> INT|DBL
#| base::which : (x:lgl, arr.ind:lgl1?, useNames:lgl1?) -> INT<>
# `nrow` and `ncol` read the `dim` attribute. The `absent` case is restricted
# to unclassed values: a data frame has no `dim`, yet `nrow` gives its number
# of rows. On an argument that still contains inference variables, each
# overload is tried alone, so every call on a parameter splits the inference
# in cases: some definitions get much slower (jsonlite's apply_by_pages from
# 1.4 s to about 65 s), but more of them are typed (e.g. `seq_len(nrow(x))`).
#| base::nrow : (x:any with { dim: any, any }) -> INT1<>
#|           && (x:<> with { dim: absent, any }) -> null
#|           && (x:any) -> INT1<> | null
#| base::ncol : (x:any with { dim: any, any }) -> INT1<>
#|           && (x:<> with { dim: absent, any }) -> null
#|           && (x:any) -> INT1<> | null
# The `dim` attribute, when the type says whether it is there; the last
# overload covers the values whose attributes are not known.
#| base::dim : (x:any with { dim: 'd, any }) -> 'd & INT<>
#|          && (x:any with { dim: absent, any }) -> null
#|          && (x:any) -> INT<> | null
# As in R, setting the dimensions drops the names and the dimnames.
#| base::dim<- : (x:v('a)<`c> with { dim: any?, dimnames: any?, names: any?, `r }, v:dbl) -> v('a)<`c> with { dim: INT, dimnames: absent, names: absent, `r }
#| base::dim<- : (x:v('a)<`c> with { dim: any?, dimnames: any?, names: any?, `r }, v:null) -> v('a)<`c> with { dim: absent, dimnames: absent, names: absent, `r }

# `rep` is generic; its methods (e.g. for factors) keep the class.
#| base::rep : (x:v('a), ...: any) -> v('a)
#| base::rep : (x:{'a}, ...: any) -> {'a}
#| base::rep : (x:null, ...: any) -> null
# Not generic, but keeps the class (and drops the names).
#| base::rep.int : (x:v('a)<`c>, times:dbl) -> v('a)<`c>
#| base::rep.int : (x:{'a}, times:dbl) -> {'a}<>
#| base::rep.int : (x:null, times:dbl) -> null

#| base::as.list : (x:{'a}, ...: any) -> {'a}
#|              && (x:any, ...: any) -> { any }<>
#| base::as.list : (x:v('a), ...: any) -> { v1('a) }<>

# `as.vector` drops every attribute of an atomic vector (a factor gives its
# labels), and keeps the names of a list. A `mode` converts the elements. It is
# generic: the last arrow of the first overload covers the values of other
# classes, and covers every argument alone (see the conventions above).
#| base::as.vector : (x:v('a)<~factor, ...>, mode:"any"?) -> v('a)<>
#|                && (x:null, mode:"any"?) -> null
#|                && (x:any, mode:CHR1?) -> any
#| base::as.vector : (x:<factor, ...>, mode:"any"?) -> CHR<>
#| base::as.vector : (x:{'a}, mode:"any"|"list"?) -> {'a}<>
#| base::as.vector : (x:vec, mode:"list") -> { any }<>
#| base::as.vector : (x:vec|list|null, mode:"character") -> CHR<>
#| base::as.vector : (x:vec|list|null, mode:"numeric"|"double") -> DBL<>
#| base::as.vector : (x:vec|list|null, mode:"integer") -> INT<>
#| base::as.vector : (x:vec|list|null, mode:"logical") -> LGL<>

# A length of 1 gives a scalar: `vapply(x, f, logical(1))` asks `f` for one.
#| base::logical : (length:1) -> LGL1<> && (length:dbl1?) -> LGL<>
#| base::integer : (length:1) -> INT1<> && (length:dbl1?) -> INT<>
#| base::double : (length:1) -> DBL1<> && (length:dbl1?) -> DBL<>
#| base::numeric : (length:1) -> DBL1<> && (length:dbl1?) -> DBL<>
#| base::character : (length:1) -> CHR1<> && (length:dbl1?) -> CHR<>

# The set operations drop the attributes of their arguments. A `NULL` gives
# `NULL`: `intersect` when either argument is one, `setdiff` when `x` is,
# `union` when both are. The first overload of each covers all the arguments
# alone (see the conventions above); the others make the result precise.
#| base::union : (x:v('a)|null, y:v('a)|null) -> v('a)<> | null
#|            && (x:v('a), y:v('a)|null) -> v('a)<>
#|            && (x:v('a)|null, y:v('a)) -> v('a)<>
#| base::union : (x:null, y:null) -> null
#| base::intersect : (x:v('a)|null, y:v('a)|null) -> v('a)<> | null
#|                && (x:v('a), y:v('a)) -> v('a)<>
#| base::intersect : (x:null, y:vec|null) -> null
#|                && (x:vec|null, y:null) -> null
#| base::setdiff : (x:v('a)|null, y:vec|null) -> v('a)<> | null
#|              && (x:v('a), y:vec|null) -> v('a)<>
#| base::setdiff : (x:null, y:vec|null) -> null

# Factors are the only class `unlist` keeps. A vector is returned as it is,
# and `NULL` (as is the empty list) is `NULL`.
#| base::unlist : (x:{v('a)<~factor, ...>}, recursive:lgl1?, use.names:lgl1?) -> v('a)<>
#|             && (x:{v('a)}, recursive:lgl1?, use.names:lgl1?) -> v('a)
#| base::unlist : (x:v('a), recursive:lgl1?, use.names:lgl1?) -> v('a)
#| base::unlist : (x:null, recursive:lgl1?, use.names:lgl1?) -> null

#| base::(:) : ( from:int, to:dbl ) -> INT<>
#|          && ( from:dbl, to:dbl ) -> (INT|DBL)<>

#| base::vector : (mode: "logical"?, length: dbl1?) -> LGL<>
#| base::vector : (mode: "integer", length: dbl1?) -> INT<>
#| base::vector : (mode: "numeric"|"double", length: dbl1?) -> DBL<>
#| base::vector : (mode: "complex", length: dbl1?) -> CLX<>
#| base::vector : (mode: "character", length: dbl1?) -> CHR<>
#| base::vector : (mode: "raw", length: dbl1?) -> RAW<>
#| base::vector : (mode: "list", length: dbl1?) -> { null&dyn }<>

#| base::matrix : (data: absent, nrow: dbl1?, ncol: dbl1?, byrow: lgl1?, dimnames: list | null?) -> LGL<> with { dim: INT, dimnames: list? }
#| base::matrix : (data: v('a), nrow: dbl1?, ncol: dbl1?, byrow: lgl1?, dimnames: list | null?) -> v('a)<> with { dim: INT, dimnames: list? }
#| base::array : (data: absent, dim: dbl?, dimnames: list | null?) -> LGL<> with { dim: INT, dimnames: list? }
#| base::array : (data: v('a), dim: dbl?, dimnames: list | null?) -> v('a)<> with { dim: INT, dimnames: list? }
# `as.matrix` is generic. The default method makes a vector a one-column
# matrix, and returns a matrix unchanged; a data frame gives a matrix of the
# mode of its columns, and the methods of other classes other matrices.
#| base::as.matrix : (x:v('a), ...: any) -> v('a)<> with { dim: INT, dimnames: list?, any }
#|                && (x:any, ...: any) -> any with { dim: INT, dimnames: list?, any }

# The sums of the columns (or rows) of a matrix or a data frame, named after
# them.
#| base::colSums : (x:any, na.rm:lgl1?, dims:dbl1?) -> DBL<>
#| base::colnames : (x:any, do.NULL:lgl1?, prefix:chr1?) -> CHR<> | null
# The row of each element of a matrix, as a matrix.
#| base::row : (x:any, as.factor:ff?) -> INT<> with { dim: INT, any }
#| base::col : (x:any, as.factor:ff?) -> INT<> with { dim: INT, any }
#| base::rownames : (x:any, do.NULL:lgl1?, prefix:chr1?) -> CHR<> | null
# The transpose: a vector is a one-row matrix. `t` is generic: a data frame
# gives a matrix (of the mode of its columns).
#| base::t : (x:v('a)) -> v('a)<> with { dim: INT, dimnames: list?, any }
#|        && (x:any) -> any with { dim: INT, dimnames: list?, any }
#| base::rowSums : (x:any, na.rm:lgl1?, dims:dbl1?) -> DBL<>

# The vectors as the columns of a matrix (`NULL`s are dropped), of the mode of
# the arguments. It is generic: a data frame among them gives a data frame.
#| base::cbind : (...: v('a)|null, deparse.level:dbl1?) -> v('a)<> with { dim: INT, dimnames: list?, any }
#|            && (...: any, deparse.level:dbl1?) -> any

# The diagonal of a matrix, or a diagonal matrix: of a vector, with it on the
# diagonal, and of a single number `n`, the identity of size `n`.
#| base::diag : (x:dbl?, nrow:dbl1?, ncol:dbl1?, names:lgl1?) -> dbl<> with { dim: INT?, dimnames: list?, names: CHR?, any }

# `as.data.frame` is generic; every method gives a data frame.
#| base::as.data.frame : (x:any, ...: any) -> { any }<data.frame> with { names: CHR, any }
#| base::data.frame : (...: any, row.names:any?, check.rows:lgl1?, check.names:lgl1?, fix.empty.names:lgl1?, stringsAsFactors:lgl1?) -> { any }<data.frame> with { names: CHR, any }
# `summary` is generic: its methods give objects of their own classes, of
# which the type says nothing (`dyn`: e.g. `summary(fit)$coefficients`).
#| base::summary : (object:any, ...: any) -> dyn

#| base::raw : (length:dbl1?) -> RAW<>
# `x` recycled (or truncated) to the length `length.out`, without attributes.
#| base::rep_len : (x:v('a), length.out:dbl1) -> v('a)<>
#| base::rep_len : (x:{'a}, length.out:dbl1) -> {'a}<>
# The position of the first maximum (minimum), named after it: of length 0
# when there is none (all `NA`, or empty).
#| base::which.max : (x:dbl|null) -> INT<>
#| base::which.min : (x:dbl|null) -> INT<>
# The vectors as the rows of a matrix: as `cbind`. The fallback is `any`,
# not `dyn`: grouped with the arrow on `v('a)`, a `dyn` result takes over
# (`rbind(1:2, 3:4)` would no longer be an integer matrix).
#| base::rbind : (...: v('a)|null, deparse.level:dbl1?) -> v('a)<> with { dim: INT, dimnames: list?, any }
#|            && (...: any, deparse.level:dbl1?) -> any
# The outer product of two arrays, of dimension `c(dim(X), dim(Y))`. With the
# default `FUN` (`"*"`), as arithmetic; otherwise, what `FUN` gives.
#| base::outer : (X:dbl, Y:dbl, FUN:"*"?) -> (DBL|INT)<> with { dim: INT, dimnames: list?, any }
#|            && (X:any, Y:any, FUN:any?, ...: any) -> any
# `x` with `STATS` swept out of its margins: with an arithmetic `FUN` (`"-"`
# by default), a numeric array of the dimensions of `x`.
#| base::sweep : (x:dbl, MARGIN:dbl, STATS:dbl, FUN:("-"|"+"|"*"|"/")?, check.margin:lgl1?, ...: any) -> (DBL|INT)<> with { dim: INT, dimnames: list?, any }
#|            && (x:any, MARGIN:dbl, STATS:any, FUN:any?, check.margin:lgl1?, ...: any) -> any
# The matrix products, of numbers or logicals.
# They are generic (e.g. Matrix's classes): on other values, a result of
# which the type says nothing but its dimensions (`dyn`: e.g.
# `1 / n * (a %*% b)`).
#| base::(%*%) : (x:dbl, y:dbl) -> (DBL|INT)<> with { dim: INT, any }
#|            && (x:any, y:any) -> dyn with { dim: INT, any }
#| base::crossprod : (x:dbl, y:dbl|null?) -> (DBL|INT)<> with { dim: INT, dimnames: list?, any }
#|                && (x:any, y:any?) -> dyn with { dim: INT, any }
# The solution of `a %*% x = b`: of a vector `b`, a vector; of a matrix `b`
# (or the inverse of `a`, without `b`), a matrix.
#| base::solve : (a:dbl, b:dbl?, ...: any) -> DBL<> with { dim: INT?, dimnames: list?, any }
# The groups of `x` defined by the factor `f`, in a list named after its
# levels. The groups keep the class of `x` (e.g. of a factor).
#| base::split : (x:v('a)<`c>, f:any, drop:lgl1?, ...: any) -> { v('a)<`c> }<>
#| base::split : (x:{'a}<`c>, f:any, drop:lgl1?, ...: any) -> { {'a}<`c> }<>
# The number of times each integer of `bin` occurs, from 1 to `nbins`.
#| base::tabulate : (bin:dbl|null, nbins:dbl1?) -> INT<>
# A contingency table: the counts of each combination of the factors.
#| base::table : (...: any, exclude:any?, useNA:CHR1?, dnn:any?, deparse.level:dbl1?) -> INT<table> with { dim: INT, dimnames: list, any }

# ========== Functionals ==========

# The extra arguments are passed along to `FUN`. The elements of a vector
# without class have none either, which the first signature says, for `FUN`
# to only accept values without class.
#| base::lapply : (X:v('a)<`c>, FUN:@(v1('a)<`c>, X:absent, FUN:absent, ...: `r) -> 'b, ...: `r) -> {'b}<>
#| base::lapply : (X:{'a}, FUN:@('a, X:absent, FUN:absent, ...: `r) -> 'b, ...: `r) -> {'b}<>
# Of `NULL`, the empty list (`FUN` is not called).
#| base::lapply : (X:null, FUN:any, ...: any) -> { }<>

#| base::vapply : (X:v('a)<>, FUN:@(v1('a)<>, X:absent, FUN:absent, FUN.VALUE:absent, ...: `r) -> v1('b), FUN.VALUE:v1('b), ...: `r) -> v('b)<>
#|             && (X:v('a), FUN:@(v1('a), X:absent, FUN:absent, FUN.VALUE:absent, ...: `r) -> v1('b), FUN.VALUE:v1('b), ...: `r) -> v('b)<>
#| base::vapply : (X:{'a}, FUN:@('a, X:absent, FUN:absent, FUN.VALUE:absent, ...: `r) -> v1('b), FUN.VALUE:v1('b), ...: `r) -> v('b)<>
# Of `NULL`, an empty vector of the type of `FUN.VALUE` (`FUN` is not called).
#| base::vapply : (X:null, FUN:any, FUN.VALUE:v1('b), ...: any) -> v('b)<>

# `sapply` simplifies the result to a vector when `FUN` returns a scalar, and
# to a matrix or a list otherwise.
#| base::sapply : (X:v('a), FUN:@(v1('a), X:absent, FUN:absent, ...: `r) -> v1('b), ...: `r) -> v('b)<>
#|             && (X:v('a), FUN:@(v1('a), X:absent, FUN:absent, ...: `r) -> any, ...: `r) -> any
#| base::sapply : (X:{'a}, FUN:@('a, X:absent, FUN:absent, ...: `r) -> v1('b), ...: `r) -> v('b)<>
#|             && (X:{'a}, FUN:@('a, X:absent, FUN:absent, ...: `r) -> any, ...: `r) -> any

# `FUN` applied to the rows (`MARGIN = 1`) or the columns (2) of a matrix, the
# results simplified as by `sapply`.
#| base::apply : (X:any, MARGIN:dbl|chr, FUN:any, ...: any, simplify:lgl1?) -> any
# `FUN` applied to the elements of the arguments in parallel. The results are
# simplified as by `sapply`, unless `SIMPLIFY = FALSE`: then it is a list.
#| base::mapply : (FUN:any, ...: any, MoreArgs:list|null?, SIMPLIFY:lgl1?, USE.NAMES:lgl1?) -> any
#|             && (FUN:any, ...: any, MoreArgs:list|null?, SIMPLIFY:ff, USE.NAMES:lgl1?) -> { any }<>

# Drawing one element gives a scalar; the size being a literal, the singleton
# type of the argument is enough to say so. A single number `n` (at least 1)
# is not drawn from, but stands for `1:n`. Drawing from `NULL` is an error.
#| base::sample : (x:v('a) \ (INT1|DBL1), size:1) -> v1('a)
#|             && (x:v('a) \ (INT1|DBL1), size:dbl1?) -> v('a)
#| base::sample : (x:INT1|DBL1, size:1) -> (INT1|DBL1)<>
#|             && (x:INT1|DBL1, size:dbl1?) -> (INT|DBL)<>
#| base::sample : (x:{'a}, size:dbl1?) -> {'a}
#| base::sample : (x:null, size:1) -> empty

# ========== Bitwise ==========

#| base::bitwNot : (a:dbl) -> INT<>
#|              && (a:dbl1) -> INT1<>

#| base::bitwAnd : (a:dbl, b:dbl) -> INT<>
#|              && (a:dbl1, b:dbl1) -> INT1<>
#| base::bitwOr : (a:dbl, b:dbl) -> INT<>
#|             && (a:dbl1, b:dbl1) -> INT1<>
#| base::bitwXor : (a:dbl, b:dbl) -> INT<>
#|              && (a:dbl1, b:dbl1) -> INT1<>

#| base::bitwShiftL : (a:dbl, n:dbl1) -> INT<>
#|                 && (a:dbl1, n:dbl1) -> INT1<>
#| base::bitwShiftR : (a:dbl, n:dbl1) -> INT<>
#|                 && (a:dbl1, n:dbl1) -> INT1<>

# ========== Maths ==========

# The functions of the `Math` group keep the class of their argument.
# Like arithmetic: a logical gives an integer, a double a double.
#| base::abs : (x:(v('a)&dbl)<`c>) -> (v('a)&(dbl\lgl) | INT)<`c>
#|          && (x:dbl1<`c>) -> dbl1<`c>
#|          && (x:DBL1<`c>) -> DBL1<`c>
#| base::round : (x:dbl1<`c>, digits:dbl1?) -> dbl1<`c>
#|            && (x:dbl<`c>, digits:dbl1?) -> dbl<`c>
#| base::signif : (x:dbl1<`c>, digits:dbl1?) -> dbl1<`c>
#|             && (x:dbl<`c>, digits:dbl1?) -> dbl<`c>
#| base::floor : (x:dbl1<`c>) -> dbl1<`c>
#|            && (x:dbl<`c>) -> dbl<`c>
#| base::ceiling : (x:dbl1<`c>) -> dbl1<`c>
#|              && (x:dbl<`c>) -> dbl<`c>
#| base::trunc : (x:dbl1<`c>, ...: any) -> dbl1<`c>
#|            && (x:dbl<`c>, ...: any) -> dbl<`c>
#| base::log : (x:dbl1<`c>, base:dbl1?) -> DBL1<`c>
#|          && (x:dbl<`c>, base:dbl1?) -> DBL<`c>
#| base::log10 : (x:dbl1<`c>) -> DBL1<`c>
#|            && (x:dbl<`c>) -> DBL<`c>
#| base::sqrt : (x:dbl1<`c>) -> DBL1<`c>
#|           && (x:dbl<`c>) -> DBL<`c>
#| base::exp : (x:dbl1<`c>) -> DBL1<`c>
#|          && (x:dbl<`c>) -> DBL<`c>
# The cumulative functions drop the class (not the names). `cumprod` is a
# double even for integers, the others are like arithmetic.
#| base::cumsum : (x:(v('a)&dbl)<`c>) -> (v('a)&(dbl\lgl) | INT)<>
#| base::cummax : (x:(v('a)&dbl)<`c>) -> (v('a)&(dbl\lgl) | INT)<>
#| base::cummin : (x:(v('a)&dbl)<`c>) -> (v('a)&(dbl\lgl) | INT)<>
#| base::cumprod : (x:dbl<`c>) -> DBL<>
# The binomial coefficients, always doubles.
#| base::choose : (n:dbl1, k:dbl1) -> DBL1<>
#|             && (n:dbl, k:dbl) -> DBL<>

# `mean` is generic; the methods of the date and time classes keep the class.
#| base::mean : (x:dbl<`c>, ...: any) -> DBL1<`c>
#|           && (x:any, ...: any) -> any

# Of an integer (or logical) vector, the result is an integer. `NULL` is an
# empty vector: `min(NULL, 1)` is `1`, `min(NULL)` is `Inf` (a double, with a
# warning), and `sum(NULL)` is `0L`. `max` and `min` keep the class of their
# arguments (the minimum of dates is a date): a result of unknown class would
# make the arithmetic on it consider the methods of every class (e.g. in
# quadprog's solve.QP, `r * (r + 5)` with `r <- min(n, q)`).
#| base::max : (...: int<`c>, na.rm:lgl1?) -> INT1<`c>
#|          && (...: dbl<`c>|null, na.rm:lgl1?) -> dbl1<`c>
#| base::min : (...: int<`c>, na.rm:lgl1?) -> INT1<`c>
#|          && (...: dbl<`c>|null, na.rm:lgl1?) -> dbl1<`c>
#| base::sum : (...: int|null, na.rm:lgl1?) -> INT1<>
#|          && (...: dbl|null, na.rm:lgl1?) -> dbl1<>
# Always a double (`prod(1:3)` is `6`, not `6L`).
#| base::prod : (...: dbl|null, na.rm:lgl1?) -> DBL1<>
# The parallel maxima and minima, elementwise; they keep the attributes of the
# first argument.
#| base::pmax : (...: int<`c>, na.rm:lgl1?) -> INT<`c>
#|           && (...: dbl<`c>, na.rm:lgl1?) -> dbl<`c>
#| base::pmin : (...: int<`c>, na.rm:lgl1?) -> INT<`c>
#|           && (...: dbl<`c>, na.rm:lgl1?) -> dbl<`c>
# The lagged differences, of the mode of `x` (a logical gives an integer). It
# is generic: the difference of dates is a `difftime`.
#| base::diff : (x:(v('a)&dbl)<>, lag:dbl1?, differences:dbl1?, ...: any) -> (v('a)&(dbl\lgl) | INT)<>
#|           && (x:any, lag:dbl1?, differences:dbl1?, ...: any) -> any
# The minimum and the maximum, a vector of length 2 (which the algebra cannot
# say), of the mode of the arguments.
#| base::range : (...: int, na.rm:lgl1?, finite:lgl1?) -> INT
#|            && (...: dbl, na.rm:lgl1?, finite:lgl1?) -> dbl
#|            && (...: CHR, na.rm:lgl1?, finite:lgl1?) -> CHR
#| base::range.default : (...: int, na.rm:lgl1?, finite:lgl1?) -> INT
#|                    && (...: dbl, na.rm:lgl1?, finite:lgl1?) -> dbl
#|                    && (...: CHR, na.rm:lgl1?, finite:lgl1?) -> CHR

# The conversions drop every attribute.
#| base::as.integer : (x:vec1) -> INT1<>
#|                 && (x:vec|null) -> INT<>
#| base::as.numeric : (x:vec1) -> DBL1<>
#|                 && (x:vec|null) -> DBL<>
#| base::as.double : (x:vec1) -> DBL1<>
#|                && (x:vec|null) -> DBL<>
#| base::as.logical : (x:vec1) -> LGL1<>
#|                 && (x:vec|null) -> LGL<>
#| base::as.character : (x:vec1) -> CHR1<>
#|                   && (x:vec|null) -> CHR<>
#| base::as.raw : (x:vec1) -> RAW1<>
#|             && (x:vec|null) -> RAW<>

#| base::asin : (x:dbl1<`c>) -> DBL1<`c>
#|           && (x:dbl<`c>) -> DBL<`c>
#| base::acos : (x:dbl1<`c>) -> DBL1<`c>
#|           && (x:dbl<`c>) -> DBL<`c>

# ========== Strings ==========

# The result is a scalar when collapsed, or when every argument is one.
#| base::paste : (...: vec1, sep:CHR1?, collapse:(chr1|null)?) -> CHR1<>
#|            && (...: any, sep:CHR1?, collapse:chr1) -> CHR1<>
#|            && (...: any, sep:CHR1?, collapse:(chr1|null)?) -> CHR<>
#| base::paste0 : (...: vec1, collapse:(chr1|null)?) -> CHR1<>
#|             && (...: any, collapse:chr1) -> CHR1<>
#|             && (...: any, collapse:(chr1|null)?) -> CHR<>

#| base::nchar : (x:chr1, type:CHR1?) -> INT1<>
#|            && (x:chr, type:CHR1?) -> INT<>
#| base::substring : (text:chr1, first:dbl1, last:dbl1?) -> CHR1<>
#|                && (text:chr, first:dbl, last:dbl?) -> CHR<>
#| base::substr : (x:chr1, start:dbl1, stop:dbl1) -> CHR1<>
#|             && (x:chr, start:dbl, stop:dbl) -> CHR<>
# `NULL` gives `character(0)`.
#| base::toupper : (x:chr1) -> CHR1<>
#|              && (x:chr|null) -> CHR<>
#| base::nzchar : (x:vec1, keepNA:lgl1?) -> LGL1<>
#|             && (x:vec|null, keepNA:lgl1?) -> LGL<>
#| base::abbreviate : (names.arg:chr|null, minlength:dbl1?, ...: any) -> CHR<>
# Syntactically valid names (`unique = TRUE`: and distinct ones).
#| base::make.names : (names:vec1, unique:lgl1?, allow_:lgl1?) -> CHR1<>
#|                 && (names:vec|null, unique:lgl1?, allow_:lgl1?) -> CHR<>
#| base::make.unique : (names:CHR, sep:CHR1?) -> CHR<>
#| base::tolower : (x:chr1) -> CHR1<>
#|              && (x:chr|null) -> CHR<>
#| base::enc2utf8 : (x:CHR1) -> CHR1<>
#|               && (x:CHR) -> CHR<>
#| base::trimws : (x:chr1, which:CHR1?) -> CHR1<>
#|             && (x:chr, which:CHR1?) -> CHR<>
# Quotes each element of `x` (after `as.character`).
#| base::sQuote : (x:vec1, q:any?) -> CHR1<>
#|             && (x:any, q:any?) -> CHR<>
#| base::dQuote : (x:vec1, q:any?) -> CHR1<>
#|             && (x:any, q:any?) -> CHR<>
# The paragraphs of `x` broken into lines of at most `width` characters: a
# vector of the lines, or a list of them per element with `simplify = FALSE`.
#| base::strwrap : (x:any, width:dbl1?, indent:dbl1?, exdent:dbl1?, prefix:chr1?, simplify:tt?, initial:chr1?) -> CHR<>
#| base::strwrap : (x:any, width:dbl1?, indent:dbl1?, exdent:dbl1?, prefix:chr1?, simplify:ff, initial:chr1?) -> { CHR<> }<>
#| base::sprintf : (fmt:CHR1, ...: vec1) -> CHR1<>
#|              && (fmt:CHR, ...: any) -> CHR<>
# `sprintf` of the translated `fmt`.
#| base::gettextf : (fmt:chr1, ...: vec1, domain:any?, trim:lgl1?) -> CHR1<>
#|               && (fmt:chr, ...: any, domain:any?, trim:lgl1?) -> CHR<>
# The singular or the plural message, depending on `n`.
#| base::ngettext : (n:dbl1, msg1:CHR1, msg2:CHR1, domain:any?) -> CHR1<>
# The lines of the source of an expression.
#| base::deparse : (expr:any, width.cutoff:dbl1?, backtick:lgl1?, control:chr?, nlines:dbl1?) -> CHR<>
#| base::format : (x:vec1, ...: any) -> CHR1<>
#|             && (x:any, ...: any) -> CHR<>
#| base::format.default : (x:vec1, ...: any) -> CHR1<>
#|                     && (x:any, ...: any) -> CHR<>
#| base::formatC : (x:vec1, ...: any) -> CHR1<>
#|              && (x:any, ...: any) -> CHR<>
# `x` formatted with marks between groups of digits (`big.mark`, ...).
#| base::prettyNum : (x:vec1, big.mark:chr1?, ...: any) -> CHR1<>
#|                && (x:vec, big.mark:chr1?, ...: any) -> CHR<>
#| base::strsplit : (x:CHR, split:chr, fixed:lgl1?, perl:lgl1?) -> { CHR<> }<>
#| base::file.path : (...: chr1, fsep:chr1?) -> CHR1<>
#|                && (...: chr, fsep:chr1?) -> CHR<>
# Unlike most path functions, `path` must be a character vector: R does not
# coerce it (`normalizePath(1)` is an error).
#| base::normalizePath : (path:CHR1, winslash:chr1?, mustWork:lgl1?) -> CHR1<>
#|                    && (path:CHR, winslash:chr1?, mustWork:lgl1?) -> CHR<>

#| base::enc2native : (x:CHR1) -> CHR1<>
#|                 && (x:CHR) -> CHR<>
# The characters of `old` in `x` replaced by those of `new`.
#| base::chartr : (old:CHR1, new:CHR1, x:chr1) -> CHR1<>
#|             && (old:CHR1, new:CHR1, x:chr|null) -> CHR<>
# `x` escaped (and quoted with `quote`), as `print` shows it.
#| base::encodeString : (x:chr1, width:dbl1|null?, quote:CHR1?, na.encode:lgl1?, justify:CHR1?) -> CHR1<>
#|                   && (x:chr, width:dbl1|null?, quote:CHR1?, na.encode:lgl1?, justify:CHR1?) -> CHR<>
# The translations of the messages.
#| base::gettext : (...: any, domain:any?, trim:lgl1?) -> CHR<>
# The bytes of a string, and back: a string, or one string per byte with
# `multiple = TRUE`.
#| base::charToRaw : (x:CHR1) -> RAW<>
#| base::rawToChar : (x:RAW, multiple:ff?) -> CHR1<>
#| base::rawToChar : (x:RAW, multiple:tt) -> CHR<>
#| base::basename : (path:CHR1) -> CHR1<>
#|               && (path:CHR) -> CHR<>
#| base::dirname : (path:CHR1) -> CHR1<>
#|              && (path:CHR) -> CHR<>
#| base::startsWith : (x:CHR1, prefix:CHR1) -> LGL1<>
#|                 && (x:CHR, prefix:CHR) -> LGL<>

# ========== Regular expressions ==========

#| base::grepl : (pattern:chr1, x:chr1, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> LGL1<>
#|            && (pattern:chr1, x:chr, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> LGL<>
# The positions of the matches, or the matching elements with `value = TRUE`.
#| base::grep : (pattern:chr1, x:chr|null, ignore.case:lgl1?, perl:lgl1?, value:ff?, fixed:lgl1?, useBytes:lgl1?, invert:lgl1?) -> INT<>
#| base::grep : (pattern:chr1, x:chr|null, ignore.case:lgl1?, perl:lgl1?, value:tt, fixed:lgl1?, useBytes:lgl1?, invert:lgl1?) -> CHR<>
#| base::sub : (pattern:chr1, replacement:chr1, x:chr1, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> CHR1<>
#|          && (pattern:chr1, replacement:chr1, x:chr, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> CHR<>
#| base::gsub : (pattern:chr1, replacement:chr1, x:chr1, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> CHR1<>
#|           && (pattern:chr1, replacement:chr1, x:chr, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> CHR<>
# regexpr returns the match position, carrying the match geometry as attributes.
# The capture groups are only reported by the Perl engine (and only when the
# pattern has some, which is assumed).
#| base::regexpr : (pattern:chr1, text:chr1, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> INT1<> with { match.length: INT1, any }
#|              && (pattern:chr1, text:chr, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> INT<> with { match.length: INT, any }
#|              && (pattern:chr1, text:chr1, ignore.case:lgl1?, perl:tt, fixed:lgl1?) -> INT1<> with { match.length: INT1, capture.start: INT, capture.length: INT, capture.names: CHR, any }
#|              && (pattern:chr1, text:chr, ignore.case:lgl1?, perl:tt, fixed:lgl1?) -> INT<> with { match.length: INT, capture.start: INT, capture.length: INT, capture.names: CHR, any }

# The positions of every match, per element of `text` (`-1` when there is
# none), with their lengths as with `regexpr`.
#| base::gregexpr : (pattern:chr1, text:chr, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?, useBytes:lgl1?) -> { INT<> with { match.length: INT, any } }<>

# ========== S3 methods ==========

# The classes of `base` built on numbers. The time classes are made of
# doubles, and a factor of the integer codes of its `levels`.
#| date = DBL<Date>
#| date1 = DBL1<Date>
#| posixct = DBL<POSIXct, POSIXt>
#| posixct1 = DBL1<POSIXct, POSIXt>
#| difftime = DBL<difftime> with { units: CHR1, any }
#| difftime1 = DBL1<difftime> with { units: CHR1, any }

#| base::Sys.Date : () -> date1
#| base::as.Date : (x:chr1, ...: any) -> date1
#|              && (x:chr|date, ...: any) -> date
#| base::as.POSIXct : (x:chr1, ...: any) -> posixct1
#|                 && (x:chr|posixct, ...: any) -> posixct
# The list-based date-times, with the components (`sec`, `min`, ...) as
# elements.
#| base::as.POSIXlt : (x:any, tz:CHR1?, ...: any) -> { any }<POSIXlt, POSIXt>
# Their methods, which packages also call directly.
#| base::as.POSIXlt.POSIXct : (x:posixct, tz:CHR1?, ...: any) -> { any }<POSIXlt, POSIXt>
#| base::as.POSIXct.POSIXlt : (x:{ any }<POSIXlt, POSIXt>, tz:CHR1?, ...: any) -> posixct
#| base::difftime : (time1:date1|posixct1, time2:date1|posixct1, tz:chr1?, units:CHR1?) -> difftime1
#|               && (time1:date|posixct, time2:date|posixct, tz:chr1?, units:CHR1?) -> difftime
#| base::as.difftime : (tim:dbl1, format:CHR1?, units:CHR1?, tz:CHR1?) -> difftime1
#|                  && (tim:dbl, format:CHR1?, units:CHR1?, tz:CHR1?) -> difftime
#| base::units : (x:<difftime, ...> with { units: 'u, any }) -> 'u
# A date-time from the number of seconds since the epoch, without checks.
#| base::.POSIXct : (xx:dbl1, tz:chr1|null?, cl:any?) -> posixct1
#|               && (xx:dbl, tz:chr1|null?, cl:any?) -> posixct
# The month (quarter) of each date, as a name (`"Q1"`, ...). They are
# generic: the methods of other classes (e.g. zoo's) give names too.
#| base::months : (x:date1|posixct1, abbreviate:lgl1?) -> CHR1<>
#|             && (x:any, abbreviate:lgl1?) -> CHR<>
#| base::quarters : (x:date1|posixct1, ...: any) -> CHR1<>
#|               && (x:any, ...: any) -> CHR<>

# The class of a factor is `factor`, or `ordered` and `factor` for an ordered
# one: its methods keep it, whichever it is.
#| base::factor : (x:vec|null?, levels:vec?, labels:chr?, ordered:ff?, ...: any) -> INT<factor> with { levels: CHR, any }
#| base::factor : (x:vec|null?, levels:vec?, labels:chr?, ordered:tt, ...: any) -> INT<ordered, factor> with { levels: CHR, any }
# An `ordered` not known statically (e.g. `is.ordered(x)`).
#| base::factor : (x:vec|null?, levels:vec?, labels:chr?, ordered:lgl1, ...: any) -> INT<factor> with { levels: CHR, any } | INT<ordered, factor> with { levels: CHR, any }
# `I` marks a value to be used as is (e.g. a column of a data frame), adding
# the `AsIs` class before its others.
#| base::I : (x:v('a)<`c>) -> v('a)<AsIs, `c>
#| base::I : (x:{'a}<`c>) -> {'a}<AsIs, `c>
#| base::levels : (x:<factor, ...> with { levels: 'l, any }) -> 'l
#|             && (x:any) -> CHR<> | null
#| base::nlevels : (x:any) -> INT1<>

# A method covers every value of its class that the default signatures of its
# generic would accept, so that a value whose class is unknown can be given a
# type: such a value may have any of these classes. Some of the cases are
# errors in R: they are given the type `empty`, as `stop`. The methods of the
# arithmetic have no type variables: they are summarised by a single arrow to
# infer the type of an application to an unknown argument (cf.
# lang/transform.ml), whose inference is much slower with variables.
#
# A date plus (or minus) a number of days, or a `difftime`, is a date: the
# class of the result is `Date` whatever the classes of the operands. The
# difference of two dates is a `difftime`. Adding two dates, or negating one,
# is an error.
#| base::(+.Date) : (e1:dbl1<Date, ...>) -> dbl1<Date, ...>
#|               && (e1:dbl<Date, ...>) -> dbl<Date, ...>
#| base::(+.Date) : (e1:DBL1<Date, ...>, e2:dbl1) -> date1
#|               && (e1:DBL<Date, ...>, e2:dbl) -> date
#|               && (e1:dbl1<Date, ...>, e2:dbl1) -> (DBL1|INT1)<Date>
#|               && (e1:dbl<Date, ...>, e2:dbl) -> (DBL|INT)<Date>
#|               && (e1:<Date, ...>, e2:<Date, ...>) -> empty
#| base::(-.Date) : (e1:<Date, ...>) -> empty
#| base::(-.Date) : (e1:DBL1<Date, ...>, e2:dbl1<~Date, ...>) -> date1
#|               && (e1:DBL<Date, ...>, e2:dbl<~Date, ...>) -> date
#|               && (e1:dbl1<Date, ...>, e2:dbl1) -> (DBL1|INT1)<Date> | difftime1
#|               && (e1:dbl<Date, ...>, e2:dbl) -> (DBL|INT)<Date> | difftime
#| base::(-.Date) : (e1:DBL1<Date, ...>, e2:DBL1<Date, ...>) -> difftime1
#|               && (e1:dbl<Date, ...>, e2:dbl<Date, ...>) -> difftime
# The subsets keep the classes of `x`.
#| base::([].Date) : (x:v('a)<Date, `c>, ...: dbl|CHR) -> v('a)<Date, `c>
#| base::([].Date) : (x:{any}<Date, ...>, ...: dbl|CHR) -> any
#| base::([[]].Date) : (x:v('a)<Date, `c>, ...: dbl|CHR) -> v1('a)<Date, `c>
#| base::([[]].Date) : (x:{any}<Date, ...>, ...: dbl|CHR) -> any

# The same for the date-times (`POSIXct`, and the list-based `POSIXlt`, which
# is converted), a number being a number of seconds. The result is a
# `POSIXct`.
#| base::(+.POSIXt) : (e1:dbl1<POSIXt, ...>) -> dbl1<POSIXt, ...>
#|                 && (e1:dbl<POSIXt, ...>) -> dbl<POSIXt, ...>
#|                 && (e1:<POSIXt, ...>) -> <POSIXt, ...>
#| base::(+.POSIXt) : (e1:DBL1<POSIXct, POSIXt, ...>, e2:dbl1) -> posixct1
#|                 && (e1:DBL<POSIXct, POSIXt, ...>, e2:dbl) -> posixct
#|                 && (e1:dbl1<POSIXt, ...>, e2:dbl1) -> (DBL1|INT1)<POSIXct, POSIXt>
#|                 && (e1:<POSIXt, ...>, e2:dbl) -> (DBL|INT)<POSIXct, POSIXt>
#|                 && (e1:<POSIXt, ...>, e2:<POSIXt, ...>) -> empty
#| base::(-.POSIXt) : (e1:<POSIXt, ...>) -> empty
#| base::(-.POSIXt) : (e1:DBL1<POSIXct, POSIXt, ...>, e2:dbl1<~POSIXt, ...>) -> posixct1
#|                 && (e1:DBL<POSIXct, POSIXt, ...>, e2:dbl<~POSIXt, ...>) -> posixct
#|                 && (e1:dbl1<POSIXt, ...>, e2:dbl1) -> (DBL1|INT1)<POSIXct, POSIXt> | difftime1
#|                 && (e1:<POSIXt, ...>, e2:dbl) -> (DBL|INT)<POSIXct, POSIXt> | difftime
#| base::(-.POSIXt) : (e1:DBL1<POSIXct, POSIXt, ...>, e2:DBL1<POSIXct, POSIXt, ...>) -> difftime1
#|                 && (e1:<POSIXt, ...>, e2:<POSIXt, ...>) -> difftime
#| base::([].POSIXct) : (x:v('a)<POSIXct, `c>, ...: dbl|CHR) -> v('a)<POSIXct, `c>
#| base::([].POSIXct) : (x:{any}<POSIXct, ...>, ...: dbl|CHR) -> any
#| base::([[]].POSIXct) : (x:v('a)<POSIXct, `c>, ...: dbl|CHR) -> v1('a)<POSIXct, `c>
#| base::([[]].POSIXct) : (x:{any}<POSIXct, ...>, ...: dbl|CHR) -> any

# A `difftime` can be negated, added to and scaled by numbers: the result is
# a `difftime` in the units of the operand. Multiplying two of them, or
# dividing by one, is an error.
#| base::(+.difftime) : (e1:difftime1, e2:dbl1?) -> difftime1
#|                   && (e1:difftime, e2:dbl?) -> difftime
#|                   && (e1:dbl1<difftime, ...>, e2:dbl1?) -> (DBL1|INT1)<difftime>
#|                   && (e1:dbl<difftime, ...>, e2:dbl?) -> (DBL|INT)<difftime>
#| base::(-.difftime) : (e1:difftime1, e2:dbl1?) -> difftime1
#|                   && (e1:difftime, e2:dbl?) -> difftime
#|                   && (e1:dbl1<difftime, ...>, e2:dbl1?) -> (DBL1|INT1)<difftime>
#|                   && (e1:dbl<difftime, ...>, e2:dbl?) -> (DBL|INT)<difftime>
#| base::(*.difftime) : (e1:difftime1, e2:dbl1) -> difftime1
#|                   && (e1:difftime, e2:dbl) -> difftime
#|                   && (e1:dbl1<difftime, ...>, e2:dbl1) -> (DBL1|INT1)<difftime>
#|                   && (e1:dbl<difftime, ...>, e2:dbl) -> (DBL|INT)<difftime>
#|                   && (e1:<difftime, ...>, e2:<difftime, ...>) -> empty
#| base::(/.difftime) : (e1:difftime1, e2:dbl1) -> difftime1
#|                   && (e1:difftime, e2:dbl) -> difftime
#|                   && (e1:dbl1<difftime, ...>, e2:dbl1) -> DBL1<difftime>
#|                   && (e1:dbl<difftime, ...>, e2:dbl) -> DBL<difftime>
#|                   && (e1:<difftime, ...>, e2:<difftime, ...>) -> empty
#| base::([].difftime) : (x:v('a)<difftime, `c> with { units: 'u, any }, ...: dbl|CHR) -> v('a)<difftime, `c> with { units: 'u, any }
#|                    && (x:v('a)<difftime, `c>, ...: dbl|CHR) -> v('a)<difftime, `c>
#| base::([].difftime) : (x:{any}<difftime, ...>, ...: dbl|CHR) -> any

# The arithmetic of factors is not meaningful: it gives `NA` (with a warning),
# as long as the longest operand. Their subsets keep their classes and levels.
#| base::(+.factor) : (e1:vec1<factor, ...>, e2:vec1?) -> LGL1<>
#|                 && (e1:<factor, ...>, e2:any?) -> LGL<>
#| base::(-.factor) : (e1:vec1<factor, ...>, e2:vec1?) -> LGL1<>
#|                 && (e1:<factor, ...>, e2:any?) -> LGL<>
#| base::(*.factor) : (e1:vec1<factor, ...>, e2:vec1) -> LGL1<>
#|                 && (e1:<factor, ...>, e2:any) -> LGL<>
#| base::(/.factor) : (e1:vec1<factor, ...>, e2:vec1) -> LGL1<>
#|                 && (e1:<factor, ...>, e2:any) -> LGL<>
#| base::([].factor) : (x:v('a)<factor, `c> with { levels: 'l, any }, ...: dbl|CHR, drop:lgl1?) -> v('a)<factor, `c> with { levels: 'l, any }
#|                  && (x:v('a)<factor, `c>, ...: dbl|CHR, drop:lgl1?) -> v('a)<factor, `c>
#| base::([].factor) : (x:{any}<factor, ...>, ...: dbl|CHR, drop:lgl1?) -> any
#| base::([[]].factor) : (x:v('a)<factor, `c> with { levels: 'l, any }, ...: dbl|CHR) -> v1('a)<factor, `c> with { levels: 'l, any }
#|                    && (x:v('a)<factor, `c>, ...: dbl|CHR) -> v1('a)<factor, `c>
#| base::([[]].factor) : (x:{any}<factor, ...>, ...: dbl|CHR) -> any

# `getRversion` is not declared. A version is a list of integer vectors, which
# compares with a string through its `Ops` method: as a class-overload of the
# comparisons, or as a plain overload, that method would show in the type of
# every comparison of a parameter, and without it, `getRversion() >= "4.0"`
# fails where an unbound `getRversion` is `dyn` in gradual mode.

# ========== Input and output ==========

#| base::identity : ( x:'a ) -> 'a
#| base::force : (x:'a) -> 'a
# Since R 4.4.0.
#| base::(%||%) : ( x:null, y:'b ) -> 'b
#| base::(%||%) : ( x:~null & 'a, y:any ) -> 'a
#| base::print : ( x:'a, ...: any ) -> 'a
#| base::invisible : ( x:'a ) -> 'a
#| base::invisible : () -> null
#| base::stdout : () -> INT1<terminal, connection>
#| base::write : ( x:any, file:(<connection, ...>|chr1)? ) -> null
#| base::cat : ( ...: any, file:any?, sep:CHR?, fill:any?, labels:CHR?, append:lgl1? ) -> null
#| base::sink : ( file:any?, append:lgl1?, type:CHR1?, split:lgl1? ) -> null
#| base::open : ( con:<connection, ...>, ...: any ) -> null
#| base::close : ( con:<connection, ...>, ...: any ) -> null
# A file connection (its `conn_id` is an external pointer).
#| base::file : ( description:CHR1?, open:CHR1?, ...: any ) -> INT1<file, connection>
#| base::isOpen : ( con:<connection, ...>, rw:chr1? ) -> LGL1<>
#| base::isatty : ( con:any ) -> LGL1<>
#| base::flush : ( con:<connection, ...> ) -> null
# A connection to a raw vector, read from, or written to (`open = "w"`).
#| base::rawConnection : ( object:RAW, open:CHR1? ) -> INT1<rawConnection, connection>
#| base::writeLines : ( text:CHR?, con:(<connection, ...>)?, sep:CHR1?, useBytes:lgl1? ) -> null
#| base::sink.number : ( type:CHR1? ) -> INT1<>
#| base::message : ( ...: any, domain:any?, appendLF:lgl1? ) -> null

#| base::stdin : () -> INT1<terminal, connection>
#| base::stderr : () -> INT1<terminal, connection>
# Whether each file exists.
#| base::file.exists : (...: CHR) -> LGL<>
#| base::dir.exists : (paths:CHR) -> LGL<>
#| base::packageStartupMessage : (...: any, domain:any?, appendLF:lgl1?) -> null

# ========== Session and environment ==========

#| base::Sys.getenv : (x:chr1, unset:chr1?) -> CHR1<>
#|                 && (x:chr, unset:chr1?) -> CHR<>
#| base::Sys.setenv : (...: any) -> LGL<>
#| base::Sys.time : () -> DBL1<POSIXct, POSIXt>
#| base::getOption : (x:CHR1, default:'a?) -> 'a | null
#| base::options : (...: any) -> { any }<>
#| base::l10n_info : () -> { any }<>
#| base::interactive : () -> LGL1<>
#| base::Sys.getlocale : (category:CHR1?) -> CHR1<>
#| base::Sys.setlocale : (category:CHR1?, locale:CHR1?) -> CHR1<>
#| base::capabilities : (what:chr?, ...: any) -> LGL<>
#| base::tempdir : (check:lgl1?) -> CHR1<>
#| base::tempfile : (pattern:CHR?, tmpdir:CHR?, fileext:CHR?) -> CHR<>
# 0 for success, 1 for failure.
#| base::unlink : (x:chr, recursive:lgl1?, force:lgl1?, expand:lgl1?) -> INT1<>
# The path of a file of an installed package, `""` when it is not found.
#| base::system.file : (...: chr1, package:chr1?, lib.loc:chr|null?, mustWork:lgl1?) -> CHR1<>
#|                  && (...: chr, package:chr1?, lib.loc:chr|null?, mustWork:lgl1?) -> CHR<>
# Named: `sysname`, `release`, `user`, ...
#| base::Sys.info : () -> CHR<> with { names: CHR, any }
# The paths of the executables (`""` when not found), named after them.
#| base::Sys.which : (names:chr1) -> CHR1<>
#|                && (names:chr) -> CHR<>
#| base::getwd : () -> CHR1<>
# Whether the directory was created (with a warning when it was not).
#| base::dir.create : (path:CHR, showWarnings:lgl1?, recursive:lgl1?, mode:any?) -> LGL1<>
# Returns the previous working directory (invisibly).
#| base::setwd : (dir:CHR1) -> CHR1<>
#| base::.libPaths : (new:CHR?, include.site:lgl1?) -> CHR<>
#| base::requireNamespace : (package:chr1, ...: any, quietly:lgl1?) -> LGL1<>
#| base::asNamespace : (ns:CHR1|env, base.OK:lgl1?) -> env

# Environments. `environment()` of a primitive is `NULL`.
#| base::parent.frame : (n:dbl1?) -> env
#| base::environment : (fun:null?) -> env
#| base::environmentName : (env:any) -> CHR1<>
#| base::isNamespaceLoaded : (name:chr1) -> LGL1<>
#| base::is.vector : (x:any, mode:CHR1?) -> LGL1<>
#| base::isS4 : (object:any) -> LGL1<>
#| base::is.pairlist : (x:any) -> LGL1<>
# The column of the maximum of each row of a matrix.
#| base::max.col : (m:dbl, ties.method:CHR1?) -> INT<>
# Sets the step of the torture of the garbage collector, and returns the
# previous one.
#| base::gctorture2 : (step:dbl1, wait:dbl1?, inhibit_release:lgl1?) -> INT1<>
#|                  && (fun:any) -> env | null
#| base::new.env : (hash:lgl1?, parent:env?, size:dbl1?) -> env
#| base::emptyenv : () -> env
#| base::globalenv : () -> env
#| base::topenv : (envir:env?, matchThisEnv:env?) -> env
# A pairlist of the frames of the calls on the stack, `NULL` at top level.
#| base::sys.frames : () -> { env }<> | null
#| base::ls : (name:any?, ...: any) -> CHR<>
#| base::objects : (name:any?, ...: any) -> CHR<>
#| base::exists : (x:CHR1, where:any?, envir:any?, frame:dbl1?, mode:CHR1?, inherits:lgl1?) -> LGL1<>
# The calls on the stack, `NULL` at top level.
#| base::sys.calls : () -> { any }<> | null
# The kinds of random number generators in use (before the change).
#| base::RNGkind : (kind:CHR1|null?, normal.kind:CHR1|null?, sample.kind:CHR1|null?) -> CHR<>
#| base::get : (x:CHR1, ...: any) -> any
# Like `get`, with `ifnotfound` (`NULL` by default) when there is no binding.
#| base::get0 : (x:CHR1, envir:any?, mode:CHR1?, inherits:lgl1?, ifnotfound:any?) -> any
# An exported object of a namespace (`pkg::name`), of which the type says
# nothing.
#| base::getExportedValue : (ns:CHR1|env, name:CHR1) -> dyn

#| base::.Platform : { OS.type: CHR1, file.sep: CHR1, path.sep: CHR1, GUI: CHR1, any }<>
#| base::.Machine : { integer.max: INT1, double.eps: DBL1, double.xmax: DBL1, sizeof.pointer: INT1, any }<>
#| base::pi : ^DBL1<>

#| base::R.home : (component:chr1?) -> CHR1<>
#| base::set.seed : (seed:dbl1|null, kind:CHR1|null?, normal.kind:CHR1|null?, sample.kind:CHR1|null?) -> null
#| base::baseenv : () -> env
#| base::getNamespace : (name:chr1|env) -> env
# Loads (unloads) the DLL of a package. A DLL is described by a "DLLInfo"
# list, whose `$` is also a method that finds a native symbol of the DLL
# (hence the `any` for other names). Without `chname`, `library.dynam` returns
# the DLLs loaded by packages, a "DLLInfoList". `libpath` goes to
# `normalizePath`, which does not coerce it.
#| base::library.dynam : (chname:absent, package:any?, lib.loc:any?, verbose:lgl1?, file.ext:chr1?, ...: any) -> { { name: CHR1, path: CHR1, dynamicLookup: LGL1, handle: externalptr<DLLHandle>, info: externalptr<DLLInfoReference>, forceSymbols: LGL1, any }<DLLInfo> }<DLLInfoList>
#| base::library.dynam : (chname:chr1, package:chr, lib.loc:chr|null?, verbose:lgl1?, file.ext:chr1?, ...: any) -> { name: CHR1, path: CHR1, dynamicLookup: LGL1, handle: externalptr<DLLHandle>, info: externalptr<DLLInfoReference>, forceSymbols: LGL1, any }<DLLInfo>
#| base::library.dynam.unload : (chname:chr1, libpath:CHR1, verbose:lgl1?, file.ext:chr1?) -> { name: CHR1, path: CHR1, dynamicLookup: LGL1, handle: externalptr<DLLHandle>, info: externalptr<DLLInfoReference>, forceSymbols: LGL1, any }<DLLInfo>
#| base::rm : (...: any, list:CHR?, pos:any?, envir:env?, inherits:lgl1?) -> null
# Binds `x` to a promise of `value`, evaluated when `x` is first used.
#| base::delayedAssign : (x:CHR1, value:any, eval.env:env?, assign.env:env?) -> null

# The global environment, and the namespace of base.
#| base::.GlobalEnv : env
#| base::.BaseNamespaceEnv : env
#| base::parent.env : (env:env) -> env
# Binds `x` to `value`, and returns `value` (invisibly).
#| base::assign : (x:CHR1, value:'a, pos:any?, envir:env?, inherits:lgl1?, immediate:lgl1?) -> 'a
# The names of the attached environments and packages.
#| base::search : () -> CHR<>
# Attaches a database (an environment, a list or a file) to the search path,
# and returns its environment.
#| base::attach : (what:any, pos:dbl1?, name:CHR1?, warn.conflicts:lgl1?) -> env
#| base::detach : (name:any?, pos:dbl1?, unload:lgl1?, character.only:lgl1?, force:lgl1?) -> null
# Attaches a package, and returns the attached packages (invisibly).
#| base::library : (package:any?, help:any?, pos:dbl1?, lib.loc:CHR|null?, character.only:lgl1?, logical.return:lgl1?, warn.conflicts:lgl1?, quietly:lgl1?, verbose:lgl1?, ...: any) -> CHR<>
#| base::save : (...: any) -> null
# `TRUE` and `FALSE`, as variables (which a program can rebind).
#| base::T : tt<>
#| base::F : ff<>
# The version of R (`R.version`), a list of class `simple.list`.
#| base::version : { major: CHR1, minor: CHR1, language: CHR1, version.string: CHR1, any }<"simple.list">
#| base::R.version : { major: CHR1, minor: CHR1, language: CHR1, version.string: CHR1, any }<"simple.list">

# ========== Control ==========

#| base::stop : (...: any) -> empty
#| base::stopifnot : (...: any) -> null
# TEMPORARY: S3 dispatch. `UseMethod` calls the method of the class of
# `object` and returns its result from the generic, so the type of a generic
# should be that of its methods (the union of their results). Until then,
# dispatching gives `dyn`, as does `NextMethod` (the next method's result);
# `.Generic` is the name of the generic, in a method, `.Class` the classes
# after the one of the method (with the classes already dispatched on as its
# `previous` attribute), and `.Method` the names of the methods (in the `Ops`
# group, one per operand).
#| base::UseMethod : (generic:CHR1, object:any?) -> dyn
#| base::NextMethod : (generic:CHR1|null?, object:any?, ...: any) -> dyn
#| base::.Generic : dyn
#| base::.Class : dyn
#| base::.Method : dyn
# Its argument is not evaluated: it is evaluated when the function exits.
#| base::on.exit : (expr:any?, add:lgl1?, after:lgl1?) -> null
# A warning (that the function is deprecated); returns `NULL` invisibly.
#| base::.Deprecated : (new:chr1?, package:chr1|null?, msg:chr1?, old:chr1?) -> null
# Signals a condition, and returns `NULL` when no handler takes it.
#| base::signalCondition : (cond:any, message:any?, call:any?) -> null
# The value of `expr` in `envir`: an expression whose type is not known.
#| base::eval : (expr:any, envir:any?, enclos:any?) -> dyn
# The value of `expr`, or the result of the handler (in `...`, named after the
# class of the condition) of the condition it signals. A handler is given the
# condition: a list with a `message` (a vector for rlang's conditions) and a
# `call`. `finally` is evaluated last, for its effects. As arguments are
# evaluated before the call, an `expr` that always signals (e.g. `stop()`)
# makes the whole call `empty`.
#| base::tryCatch : (expr:'a, ...: @({ message: CHR, call: any, any }) -> 'b, finally:any?) -> 'a | 'b
# The value of `expr`, or, when it signals an error, the error message (of
# class `try-error`, invisibly), with the condition as an attribute.
#| base::try : (expr:'a, silent:lgl1?, outFile:any?) -> 'a | CHR1<"try-error"> with { condition: { message: CHR, call: any, any }, any }
# The value of `expr`: a handler is called where the condition is signalled,
# and its result is ignored (it returns, or leaves through a restart).
#| base::withCallingHandlers : (expr:'a, ...: @({ message: CHR, call: any, any }) -> any) -> 'a
# Leaves through a restart (e.g. "muffleWarning"): it never returns.
#| base::invokeRestart : (r:chr1|list, ...: any) -> empty
# A call or a symbol, built from a list (the function, then the arguments)
# and from a string. The algebra has no type for them.
#| base::as.call : (x:list) -> any
#| base::as.symbol : (x:chr1) -> any
# Folds `f` over `x`, from the left (or the right), starting from `init` (or
# from the first element). Without `init`, the empty `x` gives `NULL`; with
# `accumulate = TRUE`, the result is a list of the intermediate values.
#| base::Reduce : (f:any, x:any, init:any?, right:lgl1?, accumulate:lgl1?, simplify:lgl1?) -> any
# One of the choices (several with `several.ok = TRUE`). The default
# `choices` are the caller's formals, which a signature cannot see.
#| base::match.arg : (arg:CHR|null, choices:chr?, several.ok:ff?) -> CHR1<>
#|                && (arg:CHR|null, choices:chr?, several.ok:lgl1) -> CHR<>

# Its argument is the name of a formal, not evaluated, or `...` (whether no
# argument fills it), which a call passes along as its elements.
#| base::missing : (...: any) -> LGL1<>
# The number of arguments of the call, and the number of elements of `...`.
#| base::nargs : () -> INT1<>
#| base::...length : () -> INT1<>
# The formal arguments of a function (a pairlist), `NULL` for a primitive.
#| base::formals : (fun:any?, envir:env?) -> { any }<> | null
# The expression of an argument (a promise), or `expr` with the variables of
# `env` substituted: a symbol, a call or a constant.
#| base::substitute : (expr:any?, env:any?) -> any
# The elements of `yes` where `test` is true, and those of `no` elsewhere: the
# result has the length (and the attributes) of `test`.
#| base::ifelse : (test:dbl1, yes:v('a), no:v('a)) -> v1('a)<>
#|             && (test:dbl, yes:v('a), no:v('a)) -> v('a)<>
# The alternatives are evaluated lazily: the result is one of them, or `NULL`
# (invisibly) when none matches and there is no default.
#| base::switch : (EXPR:chr1|dbl1, ...: 'a) -> 'a | null
#| base::do.call : (what:any, args:{ any }, quote:lgl1?, envir:env?) -> any
# Returns the message (invisibly), unless the warning is turned into an error.
#| base::warning : (...: any) -> CHR1<>

# The value of `expr`, or, when it invokes one of the restarts of `...`, what
# that restart returns: a function of the arguments given to
# `invokeRestart`, which the type says nothing about.
#| base::withRestarts : (expr:'a, ...: any) -> 'a | dyn
# `TRUE`, or a description of the differences.
#| base::all.equal : (target:any, current:any, ...: any) -> tt<> | CHR<>
# The function `FUN` names (or is), of which the type says nothing.
#| base::match.fun : (FUN:any, descend:lgl1?) -> dyn
#| base::Negate : (f:any) -> dyn
# The language objects, of which the type says nothing yet: `dyn` rather
# than `any`, so that their uses (e.g. `parse(text = s)[[1]]`) are not
# rejected.
#| base::as.name : (x:chr1) -> dyn
#| base::expression : (...: any) -> dyn
#| base::parse : (file:any?, n:dbl1|null?, text:chr|null?, prompt:any?, keep.source:lgl1?, srcfile:any?, encoding:chr1?) -> dyn
#| base::match.call : (definition:any?, call:any?, expand.dots:lgl1?, envir:env?) -> dyn
# Its argument is not evaluated (it is the result). The body of a function,
# its formals as a function (`args`), and a call built from the name of a
# function: language objects too.
#| base::quote : (expr:any) -> dyn
#| base::body : (fun:any?) -> dyn
#| base::args : (name:any) -> dyn
#| base::call : (name:CHR1, ...: any) -> dyn
#| base::is.name : (x:any) -> LGL1<>
#| base::is.symbol : (x:any) -> LGL1<>
#| base::mode : (x:any) -> CHR1<>
#| base::asS4 : (object:'a, flag:lgl1?, complete:lgl1?) -> 'a
# A reference to source code: its positions, with its file (an environment).
#| base::srcref : (srcfile:env, lloc:dbl) -> INT<srcref> with { srcfile: env, any }
# Calls an internal function of R, of which the type says nothing.
#| base::.Internal : (call:any) -> dyn
# The call given to `.Internal` is typed as an ordinary call, so the internal
# functions a package calls this way need a signature. These are the byte-code
# compiler's (package compiler). Byte code, closures and profiling counts have
# no type of their own: `dyn`.
#| base::mkCode : (code:any, consts:any) -> dyn
#| base::bcClose : (formals:any, body:any, env:env) -> dyn
#| base::bodyCode : (fun:any) -> dyn
#| base::bcVersion : () -> INT1<>
#| base::getconst : (constBuf:any, n:dbl1) -> dyn
#| base::growconst : (constBuf:any) -> dyn
#| base::putconst : (constBuf:any, constCount:dbl1, x:any) -> INT1<>
#| base::is.builtin.internal : (x:any) -> LGL1<>
#| base::bcprofstart : () -> null
#| base::bcprofstop : () -> null
#| base::bcprofcounts : () -> dyn
#| base::load.from.file : (file:chr1) -> dyn
#| base::save.to.file : (value:any, file:chr1, ascii:lgl1) -> null
# Writes `x` as R code, and returns it (invisibly).
#| base::dput : (x:'a, file:any?, control:any?) -> 'a
# The labels of an object: generic.
#| base::labels : (object:any, ...: any) -> dyn
# The message of a condition: generic.
#| base::conditionMessage : (c:any) -> dyn
#| base::simpleError : (message:chr, call:any?) -> { message: CHR, call: any, any }<simpleError, error, condition>

# ========== Other attached packages ==========

# The functions of `graphics`, which R attaches at startup: their names are
# looked up after those of `stats` (cf. `search_path` in lang/metaEnv.ml). Those
# of `methods` are in methods.R.

# The graphical parameters: the previous values of the ones that are set (a
# list, invisibly), or the value of the one that is queried.
#| graphics::par : (...: any, no.readonly:lgl1?) -> any
# Adds lines to the current plot.
#| graphics::lines : (x:any, ...: any) -> null
