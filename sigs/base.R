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
#   A function whose result may keep the class of its argument (arithmetic,
#   `[`, ...) does not: whether it does depends on methods this file does not
#   declare.
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


# ========== Arithmetic ==========

# The mode of the result is the one of the operands (which tallying unifies),
# and its length is the one of the longest operand.
# This is technically unsound: logical operands give an integer (`TRUE + TRUE`
# is `2L`), whereas these signatures say a logical. Overloads per mode (e.g.
# `int -> INT` and `DBL -> DBL`) would be sound, but none of them covers a
# `v('a)&dbl` argument alone, which Rsem needs when the argument still contains
# inference variables (see above).
#| base::(-) : ( e1:v('a)&dbl ) -> v('a)&dbl
#| base::(-) : ( e1:dbl1 ) -> dbl1
#| base::(-) : ( e1:v('a)&dbl, e2:v('a)&dbl ) -> v('a)&dbl
#| base::(-) : ( e1:dbl1, e2:dbl1 ) -> dbl1

#| base::(+) : ( e1:v('a)&dbl ) -> v('a)&dbl
#| base::(+) : ( e1:dbl1 ) -> dbl1
#| base::(+) : ( e1:v('a)&dbl, e2:v('a)&dbl ) -> v('a)&dbl
#| base::(+) : ( e1:dbl1, e2:dbl1 ) -> dbl1

#| base::(*) : ( e1:v('a)&dbl, e2:v('a)&dbl ) -> v('a)&dbl
#| base::(*) : ( e1:dbl1, e2:dbl1 ) -> dbl1
#| base::(%%) : ( e1:v('a)&dbl, e2:v('a)&dbl ) -> v('a)&dbl
#| base::(%%) : ( e1:dbl1, e2:dbl1 ) -> dbl1
#| base::(%/%) : ( e1:v('a)&dbl, e2:v('a)&dbl ) -> v('a)&dbl
#| base::(%/%) : ( e1:dbl1, e2:dbl1 ) -> dbl1

# Always a double, even for integer operands (`1L / 2L` is `0.5`).
#| base::(/) : ( e1:dbl, e2:dbl ) -> DBL
#| base::(/) : ( e1:dbl1, e2:dbl1 ) -> DBL1
#| base::(^) : ( e1:dbl, e2:dbl ) -> DBL
#| base::(^) : ( e1:dbl1, e2:dbl1 ) -> DBL1

# ========== Comparisons and Boolean operators ==========

# Contrarily to arithmetic, comparisons and Boolean operators do not keep the
# class of their operands.
#| base::(<) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#| base::(<) : ( e1:vec, e2:vec ) -> LGL<>
#| base::(<=) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#| base::(<=) : ( e1:vec, e2:vec ) -> LGL<>
#| base::(>) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#| base::(>) : ( e1:vec, e2:vec ) -> LGL<>
#| base::(>=) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#| base::(>=) : ( e1:vec, e2:vec ) -> LGL<>
#| base::(==) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#| base::(==) : ( e1:vec, e2:vec ) -> LGL<>
#| base::(!=) : ( e1:vec1, e2:vec1 ) -> LGL1<>
#| base::(!=) : ( e1:vec, e2:vec ) -> LGL<>

#| base::(&&) : ( x:lgl, y:lgl ) -> LGL1<>
#| base::(&&) : ( x:tt, y:tt ) -> tt<>
#| base::(&&) : ( x:ff, y:lgl ) -> ff<>
#| base::(&&) : ( x:lgl, y:ff ) -> ff<>

#| base::(||) : ( x:lgl, y:lgl ) -> LGL1<>
#| base::(||) : ( x:ff, y:ff ) -> ff<>
#| base::(||) : ( x:tt, y:lgl ) -> tt<>
#| base::(||) : ( x:lgl, y:tt ) -> tt<>

# `!`, `&`, `|` and `xor` also take numbers (`!0` is `TRUE`), and are bitwise
# on raw vectors, hence a result of type `lgl` rather than `LGL`.
#| base::(!) : ( x:tt ) -> ff<>
#| base::(!) : ( x:ff ) -> tt<>
#| base::(!) : ( x:dbl1 ) -> lgl1<>
#| base::(!) : ( x:dbl ) -> lgl<>

#| base::(&) : ( e1:dbl1, e2:dbl1 ) -> lgl1<>
#| base::(&) : ( e1:dbl, e2:dbl ) -> lgl<>
#| base::(|) : ( e1:dbl1, e2:dbl1 ) -> lgl1<>
#| base::(|) : ( e1:dbl, e2:dbl ) -> lgl<>
#| base::xor : ( x:dbl1, y:dbl1 ) -> lgl1<>
#| base::xor : ( x:dbl, y:dbl ) -> lgl<>

# ========== Lookups ==========

#| base::($) : (x:{ #k:'a, any}, k: #k) -> 'a
#| base::($<-) : (x:{ #k:any?, `r}, k: #k, v:'b) -> { #k:'b, `r}

#| base::([]) : (x:v('a), ...: dbl|CHR) -> v('a)
#| base::([]) : (x:{'a}, ...: dbl|CHR) -> {'a}
#| base::([]<-) : (x:v('a), ...: dbl|CHR, v:v('a)) -> v('a)
#| base::([]<-) : (x:{'a}, ...: dbl|CHR, v:{'a}) -> {'a}

#| base::([[]]) : (x:v('a), ...: dbl|CHR) -> v1('a)
#| base::([[]]) : (x:{'a}, ...: dbl) -> 'a
#| base::([[]]) : (x:{'a}, ...: CHR) -> 'a|null
#| base::([[]]) : (x:{ #k:'a, any }, k: #k) -> 'a
#| base::([[]]<-) : (x:v('a), ...: dbl|CHR, v:v('a)) -> v('a)
#| base::([[]]<-) : (x:{'a}, ...: chr, v:'a) -> {'a}
#| base::([[]]<-) : (x:{ #k:any?, `r}, k: #k, v:'b) -> { #k:'b, `r}

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
#| base::structure : (.Data:{'a}, ...: any) -> {'a}
#| base::structure : (.Data:any, ...: any) -> any

# ========== Types and predicates ==========

#| base::typeof : ( x: DBL ) -> "double"<>
#| base::typeof : ( x: CHR ) -> "character"<>
#| base::typeof : ( x: LGL ) -> "logical"<>
#| base::typeof : ( x: INT ) -> "integer"<>
#| base::typeof : ( x: CLX ) -> "complex"<>
#| base::typeof : ( x: RAW ) -> "raw"<>
#| base::typeof : ( x: list ) -> "list"<>
#| base::typeof : ( x: null ) -> "NULL"<>
#| base::typeof : ( x: any ) -> CHR1<>

#| base::is.null : (x:null) -> tt<>
#| base::is.null : (x:~null) -> ff<>
#| base::is.na : (x:vec1) -> LGL1<>
#| base::is.na : (x:any) -> LGL<>
#| base::is.character : (x:CHR) -> tt<>
#| base::is.character : (x:~CHR) -> ff<>
# Factors and the date and time classes are built on numbers, but are not
# numeric for `is.numeric`: any other class keeps it `TRUE`.
#| base::is.numeric : (x:(DBL|INT)<~factor, ~Date, ~POSIXt, ~difftime, ...>) -> tt<>
#| base::is.numeric : (x:~(DBL|INT)) -> ff<>
#| base::is.numeric : (x:DBL|INT) -> LGL1<>
#| base::is.list : (x:list) -> tt<>
#| base::is.list : (x:any) -> LGL1<>
#| base::is.environment : (x:env) -> tt<>
#| base::is.environment : (x:~env) -> ff<>
#| base::is.function : (x:any) -> LGL1<>
#| base::is.factor : (x:any) -> LGL1<>
#| base::is.matrix : (x:any) -> LGL1<>
#| base::is.nan : (x:vec1) -> LGL1<>
#| base::is.nan : (x:any) -> LGL<>
#| base::is.logical : (x:LGL) -> tt<>
#| base::is.logical : (x:~LGL) -> ff<>
#| base::is.finite : (x:vec1) -> LGL1<>
#| base::is.finite : (x:any) -> LGL<>
#| base::is.infinite : (x:vec1) -> LGL1<>
#| base::is.infinite : (x:any) -> LGL<>
#| base::isTRUE : (x:~lgl) -> ff<>
#| base::isTRUE : (x:any) -> LGL1<>
#| base::isFALSE : (x:~lgl) -> ff<>
#| base::isFALSE : (x:any) -> LGL1<>
#| base::identical : (x:any, y:any, ...: any) -> LGL1<>
#| base::(%in%) : (x:vec1, table:vec|null) -> LGL1<>
#| base::(%in%) : (x:vec|null, table:vec|null) -> LGL<>
# Like `!`, they coerce numbers.
#| base::all : (...: dbl, na.rm:lgl1?) -> LGL1<>
#| base::any : (...: dbl, na.rm:lgl1?) -> LGL1<>

# ========== Vectors and lists ==========

#| base::list : (( #l_i : 'a_i )_i, ...: 'a ) -> { ( #l_i : 'a_i )_i, 'a }

# `c()` of nothing but `NULL`s (or of nothing at all) is `NULL`. The overloads
# that exclude it need a first argument `x`: it is not in R's signature of `c`,
# but matches the same calls. `c` dispatches on its first argument: its methods
# (for factors, dates, ...) keep the class, so the result is given the classes
# of `x` (which the default method in fact drops, but then `x` has typically
# none). This takes a single overload: a third one on vectors makes inference
# blow up in memory (e.g. on rematch::re_match_all1 with --gradual).
#| base::c : ( x:v('p)<`c>, ...: v('p)|null ) -> v('p)<`c>
#| base::c : ( ...: v('p)|null ) -> v('p) | null
#| base::c : ( x:{'a}, ...: {'a}|null ) -> {'a}<>
#| base::c : ( ...: {'a}|null ) -> {'a}<> | null

#| base::length : (x:any) -> INT1<>
#| base::rev : (x:v('a)) -> v('a)
#| base::rev : (x:{'a}) -> {'a}
#| base::rev : (x:null) -> null
#| base::seq_along : (along.with:any) -> INT<>
#| base::seq_len : (length.out:dbl1) -> INT<>
#| base::which : (x:lgl, arr.ind:lgl1?, useNames:lgl1?) -> INT<>
#| base::nrow : (x:any) -> INT1<> | null
#| base::ncol : (x:any) -> INT1<> | null

# `rep` is generic; its methods (e.g. for factors) keep the class.
#| base::rep : (x:v('a), ...: any) -> v('a)
#| base::rep : (x:{'a}, ...: any) -> {'a}
#| base::rep : (x:null, ...: any) -> null

#| base::as.list : (x:{'a}, ...: any) -> {'a}
#| base::as.list : (x:v('a), ...: any) -> { v1('a) }<>
#| base::as.list : (x:any, ...: any) -> { any }<>

#| base::logical : (length:dbl1?) -> LGL<>
#| base::integer : (length:dbl1?) -> INT<>
#| base::double : (length:dbl1?) -> DBL<>
#| base::numeric : (length:dbl1?) -> DBL<>
#| base::character : (length:dbl1?) -> CHR<>

# The set operations drop the attributes of their arguments.
#| base::union : (x:v('a)|null, y:v('a)|null) -> v('a)<>
#| base::intersect : (x:v('a)|null, y:v('a)|null) -> v('a)<>
#| base::setdiff : (x:v('a)|null, y:vec|null) -> v('a)<>

# Factors are the only class `unlist` keeps.
#| base::unlist : (x:{v('a)<~factor, ...>}) -> v('a)<>
#| base::unlist : (x:{v('a)}) -> v('a)

#| base::(:) : ( from:int, to:dbl ) -> INT<>
#| base::(:) : ( from:dbl, to:dbl ) -> (INT|DBL)<>

#| base::vector : (mode: "logical"?, length: dbl1?) -> LGL<>
#| base::vector : (mode: "integer", length: dbl1?) -> INT<>
#| base::vector : (mode: "numeric"|"double", length: dbl1?) -> DBL<>
#| base::vector : (mode: "complex", length: dbl1?) -> CLX<>
#| base::vector : (mode: "character", length: dbl1?) -> CHR<>
#| base::vector : (mode: "raw", length: dbl1?) -> RAW<>
#| base::vector : (mode: "list", length: dbl1?) -> { null&dyn }<>

#| base::matrix : (data: absent, nrow: dbl1?, ncol: dbl1?, byrow: lgl1?) -> LGL<>
#| base::matrix : (data: v('a), nrow: dbl1?, ncol: dbl1?, byrow: lgl1?) -> v('a)<>

# ========== Functionals ==========

# The extra arguments are passed along to `FUN`.
#| base::lapply : (X:v('a), FUN:@(v1('a), X:absent, FUN:absent, ...: `r) -> 'b, ...: `r) -> {'b}<>
#| base::lapply : (X:{'a}, FUN:@('a, X:absent, FUN:absent, ...: `r) -> 'b, ...: `r) -> {'b}<>

#| base::vapply : (X:v('a), FUN:@(v1('a), X:absent, FUN:absent, FUN.VALUE:absent, ...: `r) -> v1('b), FUN.VALUE:v1('b), ...: `r) -> v('b)<>
#| base::vapply : (X:{'a}, FUN:@('a, X:absent, FUN:absent, FUN.VALUE:absent, ...: `r) -> v1('b), FUN.VALUE:v1('b), ...: `r) -> v('b)<>

# `sapply` simplifies the result to a vector when `FUN` returns a scalar, and
# to a matrix or a list otherwise.
#| base::sapply : (X:v('a), FUN:@(v1('a), X:absent, FUN:absent, ...: `r) -> v1('b), ...: `r) -> v('b)<>
#| base::sapply : (X:{'a}, FUN:@('a, X:absent, FUN:absent, ...: `r) -> v1('b), ...: `r) -> v('b)<>
#| base::sapply : (X:v('a), FUN:@(v1('a), X:absent, FUN:absent, ...: `r) -> any, ...: `r) -> any
#| base::sapply : (X:{'a}, FUN:@('a, X:absent, FUN:absent, ...: `r) -> any, ...: `r) -> any

# Drawing one element gives a scalar; the size being a literal, the singleton
# type of the argument is enough to say so. A single number `n` (at least 1)
# is not drawn from, but stands for `1:n`. Drawing from `NULL` is an error.
#| base::sample : (x:v('a) \ (INT1|DBL1), size:1) -> v1('a)
#| base::sample : (x:v('a) \ (INT1|DBL1), size:dbl1?) -> v('a)
#| base::sample : (x:INT1|DBL1, size:1) -> (INT1|DBL1)<>
#| base::sample : (x:INT1|DBL1, size:dbl1?) -> (INT|DBL)<>
#| base::sample : (x:{'a}, size:dbl1?) -> {'a}
#| base::sample : (x:null, size:1) -> empty

# ========== Bitwise ==========

#| base::bitwNot : (a:dbl) -> INT<>
#| base::bitwNot : (a:dbl1) -> INT1<>

#| base::bitwAnd : (a:dbl, b:dbl) -> INT<>
#| base::bitwAnd : (a:dbl1, b:dbl1) -> INT1<>
#| base::bitwOr : (a:dbl, b:dbl) -> INT<>
#| base::bitwOr : (a:dbl1, b:dbl1) -> INT1<>
#| base::bitwXor : (a:dbl, b:dbl) -> INT<>
#| base::bitwXor : (a:dbl1, b:dbl1) -> INT1<>

#| base::bitwShiftL : (a:dbl, n:dbl1) -> INT<>
#| base::bitwShiftL : (a:dbl1, n:dbl1) -> INT1<>
#| base::bitwShiftR : (a:dbl, n:dbl1) -> INT<>
#| base::bitwShiftR : (a:dbl1, n:dbl1) -> INT1<>

# ========== Maths ==========

# The functions of the `Math` group keep the class of their argument.
#| base::abs : (x:v('a)&dbl) -> v('a)&dbl
#| base::abs : (x:dbl1) -> dbl1
#| base::round : (x:dbl1, digits:dbl1?) -> dbl1
#| base::round : (x:dbl, digits:dbl1?) -> dbl
#| base::signif : (x:dbl1, digits:dbl1?) -> dbl1
#| base::signif : (x:dbl, digits:dbl1?) -> dbl
#| base::floor : (x:dbl1) -> dbl1
#| base::floor : (x:dbl) -> dbl
#| base::ceiling : (x:dbl1) -> dbl1
#| base::ceiling : (x:dbl) -> dbl
#| base::trunc : (x:dbl1, ...: any) -> dbl1
#| base::trunc : (x:dbl, ...: any) -> dbl
#| base::log : (x:dbl1, base:dbl1?) -> DBL1
#| base::log : (x:dbl, base:dbl1?) -> DBL
#| base::log10 : (x:dbl1) -> DBL1
#| base::log10 : (x:dbl) -> DBL

# Of an integer (or logical) vector, the result is an integer.
#| base::max : (...: int, na.rm:lgl1?) -> INT1
#| base::max : (...: dbl, na.rm:lgl1?) -> dbl1
#| base::min : (...: int, na.rm:lgl1?) -> INT1
#| base::min : (...: dbl, na.rm:lgl1?) -> dbl1
#| base::sum : (...: int, na.rm:lgl1?) -> INT1<>
#| base::sum : (...: dbl, na.rm:lgl1?) -> dbl1<>

# The conversions drop every attribute.
#| base::as.integer : (x:vec1) -> INT1<>
#| base::as.integer : (x:vec|null) -> INT<>
#| base::as.numeric : (x:vec1) -> DBL1<>
#| base::as.numeric : (x:vec|null) -> DBL<>
#| base::as.character : (x:vec1) -> CHR1<>
#| base::as.character : (x:vec|null) -> CHR<>

# ========== Strings ==========

# The result is a scalar when collapsed, or when every argument is one.
#| base::paste : (...: vec1, sep:chr1?, collapse:(chr1|null)?) -> CHR1<>
#| base::paste : (...: any, sep:chr1?, collapse:chr1) -> CHR1<>
#| base::paste : (...: any, sep:chr1?, collapse:(chr1|null)?) -> CHR<>
#| base::paste0 : (...: vec1, collapse:(chr1|null)?) -> CHR1<>
#| base::paste0 : (...: any, collapse:chr1) -> CHR1<>
#| base::paste0 : (...: any, collapse:(chr1|null)?) -> CHR<>

#| base::nchar : (x:chr1, type:chr1?) -> INT1<>
#| base::nchar : (x:chr, type:chr1?) -> INT<>
#| base::substring : (text:chr1, first:dbl1, last:dbl1?) -> CHR1<>
#| base::substring : (text:chr, first:dbl, last:dbl?) -> CHR<>
#| base::substr : (x:chr1, start:dbl1, stop:dbl1) -> CHR1<>
#| base::substr : (x:chr, start:dbl, stop:dbl) -> CHR<>
#| base::toupper : (x:chr1) -> CHR1<>
#| base::toupper : (x:chr) -> CHR<>
#| base::tolower : (x:chr1) -> CHR1<>
#| base::tolower : (x:chr) -> CHR<>
#| base::trimws : (x:chr1, which:chr1?) -> CHR1<>
#| base::trimws : (x:chr, which:chr1?) -> CHR<>
#| base::sprintf : (fmt:chr1, ...: vec1) -> CHR1<>
#| base::sprintf : (fmt:chr, ...: any) -> CHR<>
#| base::format : (x:vec1, ...: any) -> CHR1<>
#| base::format : (x:any, ...: any) -> CHR<>
#| base::formatC : (x:vec1, ...: any) -> CHR1<>
#| base::formatC : (x:any, ...: any) -> CHR<>
#| base::strsplit : (x:chr, split:chr, fixed:lgl1?, perl:lgl1?) -> { CHR<> }<>
#| base::file.path : (...: chr1, fsep:chr1?) -> CHR1<>
#| base::file.path : (...: chr, fsep:chr1?) -> CHR<>
#| base::normalizePath : (path:chr1, winslash:chr1?, mustWork:lgl1?) -> CHR1<>
#| base::normalizePath : (path:chr, winslash:chr1?, mustWork:lgl1?) -> CHR<>

# ========== Regular expressions ==========

#| base::grepl : (pattern:chr1, x:chr1, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> LGL1<>
#| base::grepl : (pattern:chr1, x:chr, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> LGL<>
#| base::sub : (pattern:chr1, replacement:chr1, x:chr1, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> CHR1<>
#| base::sub : (pattern:chr1, replacement:chr1, x:chr, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> CHR<>
#| base::gsub : (pattern:chr1, replacement:chr1, x:chr1, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> CHR1<>
#| base::gsub : (pattern:chr1, replacement:chr1, x:chr, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> CHR<>
# regexpr returns the match position, carrying the match geometry as attributes.
# The capture groups are only reported by the Perl engine (and only when the
# pattern has some, which is assumed).
#| base::regexpr : (pattern:chr1, text:chr1, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> INT1<> with { match.length: INT1, any }
#| base::regexpr : (pattern:chr1, text:chr, ignore.case:lgl1?, perl:lgl1?, fixed:lgl1?) -> INT<> with { match.length: INT, any }
#| base::regexpr : (pattern:chr1, text:chr1, ignore.case:lgl1?, perl:tt, fixed:lgl1?) -> INT1<> with { match.length: INT1, capture.start: INT, capture.length: INT, capture.names: CHR, any }
#| base::regexpr : (pattern:chr1, text:chr, ignore.case:lgl1?, perl:tt, fixed:lgl1?) -> INT<> with { match.length: INT, capture.start: INT, capture.length: INT, capture.names: CHR, any }

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
#| base::Sys.getenv : (x:chr, unset:chr1?) -> CHR<>
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
#| base::environment : (fun:any) -> env | null
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

# ========== Control ==========

#| base::stop : (...: any) -> empty
#| base::stopifnot : (...: any) -> null
# One of the choices (several with `several.ok = TRUE`). The default
# `choices` are the caller's formals, which a signature cannot see.
#| base::match.arg : (arg:chr|null, choices:chr?, several.ok:ff?) -> CHR1<>
#| base::match.arg : (arg:chr|null, choices:chr?, several.ok:lgl1) -> CHR<>

# Its argument is the name of a formal, not evaluated.
#| base::missing : (x:any) -> LGL1<>
# The alternatives are evaluated lazily: the result is one of them, or `NULL`
# (invisibly) when none matches and there is no default.
#| base::switch : (EXPR:chr1|dbl1, ...: 'a) -> 'a | null
#| base::do.call : (what:any, args:{ any }, quote:lgl1?, envir:env?) -> any
# Returns the message (invisibly), unless the warning is turned into an error.
#| base::warning : (...: any) -> CHR1<>
