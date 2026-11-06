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
#| base::(-) : ( e1:(v('a)&dbl)<`c> ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|          && ( e1:dbl1<`c> ) -> dbl1<`c>
#|          && ( e1:DBL1<`c> ) -> DBL1<`c>
#| base::(-) : ( e1:(v('a)&dbl)<`c>, e2:(v('a)&dbl)<`c> ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|          && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> dbl1<`c>
#|          && ( e1:DBL1<`c>, e2:dbl1<`c> ) -> DBL1<`c>
#|          && ( e1:dbl1<`c>, e2:DBL1<`c> ) -> DBL1<`c>

#| base::(+) : ( e1:(v('a)&dbl)<`c> ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|          && ( e1:dbl1<`c> ) -> dbl1<`c>
#|          && ( e1:DBL1<`c> ) -> DBL1<`c>
#| base::(+) : ( e1:(v('a)&dbl)<`c>, e2:(v('a)&dbl)<`c> ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|          && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> dbl1<`c>
#|          && ( e1:DBL1<`c>, e2:dbl1<`c> ) -> DBL1<`c>
#|          && ( e1:dbl1<`c>, e2:DBL1<`c> ) -> DBL1<`c>

#| base::(*) : ( e1:(v('a)&dbl)<`c>, e2:(v('a)&dbl)<`c> ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|          && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> dbl1<`c>
#|          && ( e1:DBL1<`c>, e2:dbl1<`c> ) -> DBL1<`c>
#|          && ( e1:dbl1<`c>, e2:DBL1<`c> ) -> DBL1<`c>
#| base::(%%) : ( e1:(v('a)&dbl)<`c>, e2:(v('a)&dbl)<`c> ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|           && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> dbl1<`c>
#|           && ( e1:DBL1<`c>, e2:dbl1<`c> ) -> DBL1<`c>
#|           && ( e1:dbl1<`c>, e2:DBL1<`c> ) -> DBL1<`c>
#| base::(%/%) : ( e1:(v('a)&dbl)<`c>, e2:(v('a)&dbl)<`c> ) -> (v('a)&(dbl\lgl) | INT)<`c>
#|            && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> dbl1<`c>
#|            && ( e1:DBL1<`c>, e2:dbl1<`c> ) -> DBL1<`c>
#|            && ( e1:dbl1<`c>, e2:DBL1<`c> ) -> DBL1<`c>

# Always a double, even for integer operands (`1L / 2L` is `0.5`).
#| base::(/) : ( e1:dbl<`c>, e2:dbl<`c> ) -> DBL<`c>
#|          && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> DBL1<`c>
#| base::(^) : ( e1:dbl<`c>, e2:dbl<`c> ) -> DBL<`c>
#|          && ( e1:dbl1<`c>, e2:dbl1<`c> ) -> DBL1<`c>

# ========== Comparisons and Boolean operators ==========

# Contrarily to arithmetic, comparisons and Boolean operators do not keep the
# class of their operands.
#| base::(<) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#|          && ( e1:vec, e2:vec ) -> LGL<>
#| base::(<=) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#|           && ( e1:vec, e2:vec ) -> LGL<>
#| base::(>) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#|          && ( e1:vec, e2:vec ) -> LGL<>
#| base::(>=) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#|           && ( e1:vec, e2:vec ) -> LGL<>
#| base::(==) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#|           && ( e1:vec, e2:vec ) -> LGL<>
#| base::(!=) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#|           && ( e1:vec, e2:vec ) -> LGL<>

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

# The default subsets drop the class (the classes whose methods keep it
# overload them, cf. "S3 methods"), and so does `[[` of an atomic vector. A
# replacement keeps the attributes of `x`, its class among them.
#| base::([]) : (x:v('a), ...: dbl|CHR) -> v('a)<>
#| base::([]) : (x:{'a}, ...: dbl|CHR) -> {'a}<>
#| base::([]<-) : (x:v('a)<`c>, ...: dbl|CHR, v:v('a)) -> v('a)<`c>
#| base::([]<-) : (x:{'a}<`c>, ...: dbl|CHR, v:{'a}) -> {'a}<`c>

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
#| base::class<- : (x:'a<...>, v:chr) -> 'a<...>
#| base::class<- : (x:'a<...>, v:null) -> 'a<>
#| base::unclass : (x:'a<...>) -> 'a<>
#| base::inherits : (x:any, what:chr, which:ff?) -> LGL1<>
#| base::inherits : (x:any, what:chr, which:tt) -> INT<>

#| base::names : (x:any) -> CHR<> | null
#| base::names<- : (x:'a, v:chr|null) -> 'a

# The attribute is selected by a literal name, so the label is polymorphic.
#| base::attr : (x:any with { #k:'b, any }, which: #k, exact:lgl1?) -> 'b

#| base::attributes : (x:any) -> { any }<> | null

# The attributes it sets, the class among them, are not tracked: the result has
# the type of `.Data` with any attributes.
#| base::structure : (.Data:v('a), ...: any) -> v('a)
#|                && (.Data:any, ...: any) -> any
#| base::structure : (.Data:{'a}, ...: any) -> {'a}

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
#| base::is.character : (x:CHR) -> tt<>
#| base::is.character : (x:~CHR) -> ff<>
# Factors and the date and time classes are built on numbers, but are not
# numeric for `is.numeric`: any other class keeps it `TRUE`.
#| base::is.numeric : (x:(DBL|INT)<~factor, ~Date, ~POSIXt, ~difftime, ...>) -> tt<>
#|                 && (x:DBL|INT) -> LGL1<>
#| base::is.numeric : (x:~(DBL|INT)) -> ff<>
#| base::is.list : (x:list) -> tt<>
#|              && (x:any) -> LGL1<>
#| base::is.environment : (x:env) -> tt<>
#| base::is.environment : (x:~env) -> ff<>
#| base::is.function : (x:any) -> LGL1<>
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
# Like `!`, they coerce numbers.
#| base::all : (...: dbl, na.rm:lgl1?) -> LGL1<>
#| base::any : (...: dbl, na.rm:lgl1?) -> LGL1<>

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
#| base::c : ( x:v('p)<`c>, ...: v('p)|null ) -> v('p)<`c>
#|        && ( ...: v('p)|null ) -> v('p) | null
#| base::c : ( x:{'a}, ...: {'a}|null ) -> {'a}<>
#|        && ( ...: {'a}|null ) -> {'a}<> | null

#| base::length : (x:any) -> INT1<>
#| base::rev : (x:v('a)) -> v('a)
#| base::rev : (x:{'a}) -> {'a}
#| base::rev : (x:null) -> null
#| base::seq_along : (along.with:any) -> INT<>
#| base::seq_len : (length.out:dbl1) -> INT<>
# `seq` is generic: its methods (for dates, ...) keep the class. A single
# `from` of length other than 1 is `seq_along(from)`. `to` and `by` must have
# length 1, but are vectors here: `x[1L]`, their usual source, is not a scalar
# for the algebra.
#| base::seq : (from:dbl?, to:dbl?, by:dbl?, length.out:dbl1?, along.with:any?, ...: any) -> INT|DBL
#| base::which : (x:lgl, arr.ind:lgl1?, useNames:lgl1?) -> INT<>
#| base::nrow : (x:any) -> INT1<> | null
#| base::ncol : (x:any) -> INT1<> | null

# `rep` is generic; its methods (e.g. for factors) keep the class.
#| base::rep : (x:v('a), ...: any) -> v('a)
#| base::rep : (x:{'a}, ...: any) -> {'a}
#| base::rep : (x:null, ...: any) -> null

#| base::as.list : (x:{'a}, ...: any) -> {'a}
#|              && (x:any, ...: any) -> { any }<>
#| base::as.list : (x:v('a), ...: any) -> { v1('a) }<>

#| base::logical : (length:dbl1?) -> LGL<>
#| base::integer : (length:dbl1?) -> INT<>
#| base::double : (length:dbl1?) -> DBL<>
#| base::numeric : (length:dbl1?) -> DBL<>
#| base::character : (length:dbl1?) -> CHR<>

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

# Factors are the only class `unlist` keeps.
#| base::unlist : (x:{v('a)<~factor, ...>}) -> v('a)<>
#|             && (x:{v('a)}) -> v('a)

#| base::(:) : ( from:int, to:dbl ) -> INT<>
#|          && ( from:dbl, to:dbl ) -> (INT|DBL)<>

#| base::vector : (mode: "logical"?, length: dbl1?) -> LGL<>
#| base::vector : (mode: "integer", length: dbl1?) -> INT<>
#| base::vector : (mode: "numeric"|"double", length: dbl1?) -> DBL<>
#| base::vector : (mode: "complex", length: dbl1?) -> CLX<>
#| base::vector : (mode: "character", length: dbl1?) -> CHR<>
#| base::vector : (mode: "raw", length: dbl1?) -> RAW<>
#| base::vector : (mode: "list", length: dbl1?) -> { null&dyn }<>

#| base::matrix : (data: absent, nrow: dbl1?, ncol: dbl1?, byrow: lgl1?, dimnames: list | null?) -> LGL<>
#| base::matrix : (data: v('a), nrow: dbl1?, ncol: dbl1?, byrow: lgl1?, dimnames: list | null?) -> v('a)<>

# ========== Functionals ==========

# The extra arguments are passed along to `FUN`. The elements of a vector
# without class have none either, which the first signature says, for `FUN`
# to only accept values without class.
#| base::lapply : (X:v('a)<`c>, FUN:@(v1('a)<`c>, X:absent, FUN:absent, ...: `r) -> 'b, ...: `r) -> {'b}<>
#| base::lapply : (X:{'a}, FUN:@('a, X:absent, FUN:absent, ...: `r) -> 'b, ...: `r) -> {'b}<>

#| base::vapply : (X:v('a)<>, FUN:@(v1('a)<>, X:absent, FUN:absent, FUN.VALUE:absent, ...: `r) -> v1('b), FUN.VALUE:v1('b), ...: `r) -> v('b)<>
#|             && (X:v('a), FUN:@(v1('a), X:absent, FUN:absent, FUN.VALUE:absent, ...: `r) -> v1('b), FUN.VALUE:v1('b), ...: `r) -> v('b)<>
#| base::vapply : (X:{'a}, FUN:@('a, X:absent, FUN:absent, FUN.VALUE:absent, ...: `r) -> v1('b), FUN.VALUE:v1('b), ...: `r) -> v('b)<>

# `sapply` simplifies the result to a vector when `FUN` returns a scalar, and
# to a matrix or a list otherwise.
#| base::sapply : (X:v('a), FUN:@(v1('a), X:absent, FUN:absent, ...: `r) -> v1('b), ...: `r) -> v('b)<>
#|             && (X:v('a), FUN:@(v1('a), X:absent, FUN:absent, ...: `r) -> any, ...: `r) -> any
#| base::sapply : (X:{'a}, FUN:@('a, X:absent, FUN:absent, ...: `r) -> v1('b), ...: `r) -> v('b)<>
#|             && (X:{'a}, FUN:@('a, X:absent, FUN:absent, ...: `r) -> any, ...: `r) -> any

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

# Of an integer (or logical) vector, the result is an integer.
#| base::max : (...: int, na.rm:lgl1?) -> INT1
#|          && (...: dbl, na.rm:lgl1?) -> dbl1
#| base::min : (...: int, na.rm:lgl1?) -> INT1
#|          && (...: dbl, na.rm:lgl1?) -> dbl1
#| base::sum : (...: int, na.rm:lgl1?) -> INT1<>
#|          && (...: dbl, na.rm:lgl1?) -> dbl1<>
# The minimum and the maximum, a vector of length 2 (which the algebra cannot
# say), of the mode of the arguments.
#| base::range : (...: int, na.rm:lgl1?, finite:lgl1?) -> INT
#|            && (...: dbl, na.rm:lgl1?, finite:lgl1?) -> dbl
#|            && (...: CHR, na.rm:lgl1?, finite:lgl1?) -> CHR

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

# ========== Strings ==========

# The result is a scalar when collapsed, or when every argument is one.
#| base::paste : (...: vec1, sep:chr1?, collapse:(chr1|null)?) -> CHR1<>
#|            && (...: any, sep:chr1?, collapse:chr1) -> CHR1<>
#|            && (...: any, sep:chr1?, collapse:(chr1|null)?) -> CHR<>
#| base::paste0 : (...: vec1, collapse:(chr1|null)?) -> CHR1<>
#|             && (...: any, collapse:chr1) -> CHR1<>
#|             && (...: any, collapse:(chr1|null)?) -> CHR<>

#| base::nchar : (x:chr1, type:chr1?) -> INT1<>
#|            && (x:chr, type:chr1?) -> INT<>
#| base::substring : (text:chr1, first:dbl1, last:dbl1?) -> CHR1<>
#|                && (text:chr, first:dbl, last:dbl?) -> CHR<>
#| base::substr : (x:chr1, start:dbl1, stop:dbl1) -> CHR1<>
#|             && (x:chr, start:dbl, stop:dbl) -> CHR<>
#| base::toupper : (x:chr1) -> CHR1<>
#|              && (x:chr) -> CHR<>
#| base::tolower : (x:chr1) -> CHR1<>
#|              && (x:chr) -> CHR<>
#| base::trimws : (x:chr1, which:chr1?) -> CHR1<>
#|             && (x:chr, which:chr1?) -> CHR<>
#| base::sprintf : (fmt:chr1, ...: vec1) -> CHR1<>
#|              && (fmt:chr, ...: any) -> CHR<>
#| base::format : (x:vec1, ...: any) -> CHR1<>
#|             && (x:any, ...: any) -> CHR<>
#| base::formatC : (x:vec1, ...: any) -> CHR1<>
#|              && (x:any, ...: any) -> CHR<>
#| base::strsplit : (x:chr, split:chr, fixed:lgl1?, perl:lgl1?) -> { CHR<> }<>
#| base::file.path : (...: chr1, fsep:chr1?) -> CHR1<>
#|                && (...: chr, fsep:chr1?) -> CHR<>
#| base::normalizePath : (path:chr1, winslash:chr1?, mustWork:lgl1?) -> CHR1<>
#|                    && (path:chr, winslash:chr1?, mustWork:lgl1?) -> CHR<>

# ========== Regular expressions ==========

#| base::grepl : (pattern:chr1, x:chr1, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> LGL1<>
#|            && (pattern:chr1, x:chr, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> LGL<>
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
#| base::difftime : (time1:date1|posixct1, time2:date1|posixct1, tz:chr1?, units:chr1?) -> difftime1
#|               && (time1:date|posixct, time2:date|posixct, tz:chr1?, units:chr1?) -> difftime
#| base::as.difftime : (tim:dbl1, format:chr1?, units:chr1?, tz:chr1?) -> difftime1
#|                  && (tim:dbl, format:chr1?, units:chr1?, tz:chr1?) -> difftime
#| base::units : (x:<difftime, ...> with { units: 'u, any }) -> 'u

# The class of a factor is `factor`, or `ordered` and `factor` for an ordered
# one: its methods keep it, whichever it is.
#| base::factor : (x:vec|null?, levels:vec?, labels:chr?, ordered:ff?, ...: any) -> INT<factor> with { levels: CHR, any }
#| base::factor : (x:vec|null?, levels:vec?, labels:chr?, ordered:tt, ...: any) -> INT<ordered, factor> with { levels: CHR, any }
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

# ========== Input and output ==========

#| base::identity : ( x:'a ) -> 'a
# Since R 4.4.0.
#| base::(%||%) : ( x:null, y:'b ) -> 'b
#| base::(%||%) : ( x:~null & 'a, y:any ) -> 'a
#| base::print : ( x:'a, ...: any ) -> 'a
#| base::invisible : ( x:'a ) -> 'a
#| base::invisible : () -> null
#| base::stdout : () -> INT1<terminal, connection>
#| base::write : ( x:any, file:(<connection, ...>|chr1)? ) -> null
#| base::cat : ( ...: any, file:any?, sep:chr?, fill:any?, labels:chr?, append:lgl1? ) -> null
#| base::sink : ( file:any?, append:lgl1?, type:chr1?, split:lgl1? ) -> null
#| base::close : ( con:<connection, ...>, ...: any ) -> null

# ========== Session and environment ==========

#| base::Sys.getenv : (x:chr1, unset:chr1?) -> CHR1<>
#|                 && (x:chr, unset:chr1?) -> CHR<>
#| base::Sys.setenv : (...: any) -> LGL<>
#| base::Sys.time : () -> DBL1<POSIXct, POSIXt>
#| base::getOption : (x:chr1, default:'a?) -> 'a | null
#| base::options : (...: any) -> { any }<>
#| base::l10n_info : () -> { any }<>
#| base::interactive : () -> LGL1<>
#| base::Sys.getlocale : (category:chr1?) -> CHR1<>
#| base::Sys.setlocale : (category:chr1?, locale:chr1?) -> CHR1<>
#| base::capabilities : (what:chr?, ...: any) -> LGL<>
#| base::tempdir : (check:lgl1?) -> CHR1<>
#| base::tempfile : (pattern:chr?, tmpdir:chr?, fileext:chr?) -> CHR<>
#| base::getwd : () -> CHR1<>
# Returns the previous working directory (invisibly).
#| base::setwd : (dir:chr1) -> CHR1<>
#| base::.libPaths : (new:chr?, include.site:lgl1?) -> CHR<>
#| base::requireNamespace : (package:chr1, ...: any, quietly:lgl1?) -> LGL1<>
#| base::asNamespace : (ns:chr1|env, base.OK:lgl1?) -> env

# Environments. `environment()` of a primitive is `NULL`.
#| base::parent.frame : (n:dbl1?) -> env
#| base::environment : (fun:null?) -> env
#|                  && (fun:any) -> env | null
#| base::new.env : (hash:lgl1?, parent:env?, size:dbl1?) -> env
#| base::emptyenv : () -> env
#| base::globalenv : () -> env
#| base::topenv : (envir:env?, matchThisEnv:env?) -> env
# A pairlist of the frames of the calls on the stack, `NULL` at top level.
#| base::sys.frames : () -> { env }<> | null
#| base::ls : (name:any?, ...: any) -> CHR<>
#| base::get : (x:chr1, ...: any) -> any

#| base::.Platform : { OS.type: CHR1, file.sep: CHR1, path.sep: CHR1, GUI: CHR1, any }<>
#| base::.Machine : { integer.max: INT1, double.eps: DBL1, double.xmax: DBL1, any }<>
#| base::pi : ^DBL1<>

# ========== Control ==========

#| base::stop : (...: any) -> empty
#| base::stopifnot : (...: any) -> null
# One of the choices (several with `several.ok = TRUE`). The default
# `choices` are the caller's formals, which a signature cannot see.
#| base::match.arg : (arg:chr|null, choices:chr?, several.ok:ff?) -> CHR1<>
#|                && (arg:chr|null, choices:chr?, several.ok:lgl1) -> CHR<>

# Its argument is the name of a formal, not evaluated.
#| base::missing : (x:any) -> LGL1<>
# The alternatives are evaluated lazily: the result is one of them, or `NULL`
# (invisibly) when none matches and there is no default.
#| base::switch : (EXPR:chr1|dbl1, ...: 'a) -> 'a | null
#| base::do.call : (what:any, args:{ any }, quote:lgl1?, envir:env?) -> any
# Returns the message (invisibly), unless the warning is turned into an error.
#| base::warning : (...: any) -> CHR1<>
