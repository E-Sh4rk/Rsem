# The functions of R are declared in the namespace they come from, which is
# where an unqualified name is looked up when no definition of the program binds
# it (cf. R's search path). A program can thus redefine `paste` without
# affecting `base::paste`; overloading the base function itself is done by
# declaring another signature of `base::paste`.
#
# `isTrue`, `isFalse`, `fail` and `exit` are not R functions but helpers of the
# tests, so they are declared as global names.


# ========== Arithmetic ==========

#| base::(-) : ( x:v('a)&dbl ) -> v('a)&dbl
#| base::(-) : ( x:dbl1 ) -> dbl1
#| base::(-) : ( x:v('a)&dbl, y:v('a)&dbl) -> v('a)&dbl
#| base::(-) : ( x:dbl1, y:dbl1) -> dbl1

#| base::(+) : ( x:v('a)&dbl ) -> v('a)&dbl
#| base::(+) : ( x:dbl1 ) -> dbl1
#| base::(+) : ( x:v('a)&dbl, y:v('a)&dbl) -> v('a)&dbl
#| base::(+) : ( x:dbl1, y:dbl1) -> dbl1

#| base::(*) : ( x:v('a)&dbl, y:v('a)&dbl) -> v('a)&dbl
#| base::(*) : ( x:dbl1, y:dbl1) -> dbl1
#| base::(/) : ( x:v('a)&dbl, y:v('a)&dbl) -> v('a)&dbl
#| base::(/) : ( x:dbl1, y:dbl1) -> dbl1
#| base::(%/%) : ( x:int, y:int ) -> int
#| base::(%/%) : ( x:int1, y:int1 ) -> int1
#| base::(%%) : ( x:v('a)&dbl, y:v('a)&dbl) -> v('a)&dbl
#| base::(%%) : ( x:dbl1, y:dbl1) -> dbl1
#| base::(^) : ( x:v('a)&dbl, y:v('a)&dbl) -> v('a)&dbl
#| base::(^) : ( x:dbl1, y:dbl1) -> dbl1

#| base::abs : (x:v('a)&dbl) -> v('a)&dbl
#| base::abs : (x:dbl1) -> dbl1

# ========== IO ==========

#| base::identity : ( x:'a ) -> 'a
#| base::print : ( x:'a ) -> 'a
#| base::write : ( x:any, file:<connection>|chr ) -> null
#| base::stdout : () -> <connection>

# ========== Comparisons and Boolean operators ==========

#| base::(<) : ( x:dbl1, y:dbl1 ) -> lgl1<>
#| base::(<) : ( x:dbl, y:dbl ) -> lgl<>
#| base::(<=) : ( x:dbl1, y:dbl1 ) -> lgl1<>
#| base::(<=) : ( x:dbl, y:dbl ) -> lgl<>
#| base::(>) : ( x:dbl1, y:dbl1 ) -> lgl1<>
#| base::(>) : ( x:dbl, y:dbl ) -> lgl<>
#| base::(>=) : ( x:dbl1, y:dbl1 ) -> lgl1<>
#| base::(>=) : ( x:dbl, y:dbl ) -> lgl<>

#| base::(&&) : ( x:lgl, y:lgl ) -> lgl1<>
#| base::(&&) : ( x:tt, y:tt ) -> tt<>
#| base::(&&) : ( x:ff, y:lgl ) -> ff<>
#| base::(&&) : ( x:lgl, y:ff ) -> ff<>

#| base::(||) : ( x:lgl, y:lgl ) -> lgl1<>
#| base::(||) : ( x:ff, y:ff ) -> ff<>
#| base::(||) : ( x:tt, y:lgl ) -> tt<>
#| base::(||) : ( x:lgl, y:tt ) -> tt<>

#| base::(!) : ( x:lgl ) -> lgl<>
#| base::(!) : ( x:tt ) -> ff<>
#| base::(!) : ( x:ff ) -> tt<>

#| base::(|) : ( x:lgl, y:lgl ) -> lgl<>
#| base::(&) : ( x:lgl, y:lgl ) -> lgl<>
#| base::xor : ( x:lgl, y:lgl ) -> lgl<>

# Not R's `isTRUE`/`isFALSE`: helpers of the tests (cf. the header).
#| isTrue : (x:lgl , na: lgl1?) -> lgl<>
#| isTrue : (x:tt , na: lgl1?) -> tt<>
#| isTrue : (x:ff , na: lgl1?) -> ff<>

#| isFalse : (x:lgl , na: lgl1?) -> lgl<>
#| isFalse : (x:tt , na: lgl1?) -> ff<>
#| isFalse : (x:ff , na: lgl1?) -> tt<>

#| base::typeof : ( x: DBL ) -> "double"
#| base::typeof : ( x: CHR ) -> "character"
#| base::typeof : ( x: LGL ) -> "logical"
#| base::typeof : ( x: INT ) -> "integer"
#| base::typeof : ( x: CLX ) -> "complex"
#| base::typeof : ( x: RAW ) -> "raw"
#| base::typeof : ( x: list ) -> "list"
#| base::typeof : ( x: null ) -> "NULL"
#| fail : empty -> any
#| exit : any -> empty

# ========== Lookups ==========

#| base::($) : (x:{ #k:'a, any}, k: #k) -> 'a
#| base::($<-) : (x:{ #k:any?, `r}, k: #k, v:'b) -> { #k:'b, `r}

#| base::([]) : (x:v('a), ...: dbl|CHR) -> v('a)
#| base::([]) : (x:{'a}, ...: dbl) -> {'a}
#| base::([]<-) : (x:v('a), ...: dbl|CHR, v:v('a)) -> v('a)
#| base::([]<-) : (x:{'a}, ...: dbl, v:{'a}) -> {'a}

#| base::([[]]) : (x:v('a), ...: dbl|CHR) -> v1('a)
#| base::([[]]) : (x:{'a}, ...: dbl) -> 'a
#| base::([[]]) : (x:{'a}, ...: CHR) -> 'a|null
#| base::([[]]) : (x:{ #k:'a, any }, k: #k) -> 'a
#| base::([[]]<-) : (x:v('a), ...: dbl, v:v('a)) -> v('a)
#| base::([[]]<-) : (x:{'a}, ...: chr, v:'a) -> {'a}
#| base::([[]]<-) : (x:{ #k:any?, `r}, k: #k, v:'b) -> { #k:'b, `r}

# ========== Classes and attrs ==========

#| base::class : (x:'a<...>) -> chr
#| base::class<- : (x:'a<...> , v:chr) -> 'a<...>
#| base::unclass : (x:'a<...>) -> 'a<>

#| base::names : (x:any) -> chr
#| base::names<- : (x:'a, v:chr) -> 'a

# ========== Lists, vectors and matrices ==========

#| base::list : (( #l_i : 'a_i )_i, ...: 'a ) -> { ( #l_i : 'a_i )_i, 'a }

#| base::c : ( ...: v('p) ) -> v('p)<>

#| base::(:) : ( from:dbl, to:dbl ) -> dbl
#| base::(:) : ( from:int, to:int ) -> int

#| base::lapply : (X:v('a), FUN:@(v1('a), X:absent, FUN:absent, ...: `r) -> 'b, ...: `r) -> {'b}
#| base::lapply : (X:{'a}, FUN:@('a, X:absent, FUN:absent, ...: `r) -> 'b, ...: `r) -> {'b}

#| base::vector : (mode: "logical"?, length: dbl?) -> lgl
#| base::vector : (mode: "numeric", length: dbl?) -> dbl
#| base::vector : (mode: "character", length: dbl?) -> chr
#| base::vector : (mode: "raw", length: dbl?) -> raw
#| base::vector : (mode: "list", length: dbl?) -> { null&dyn }

#| base::matrix : (data: absent, nrow: dbl?, ncol: dbl?) -> lgl
#| base::matrix : (data: v1('a), nrow: dbl?, ncol: dbl?) -> v('a)

# ========== Bitwise ==========

#| base::bitwNot : (a:dbl) -> INT
#| base::bitwNot : (a:dbl1) -> INT1

#| base::bitwAnd : (a:dbl, b:dbl) -> INT
#| base::bitwAnd : (a:dbl1, b:dbl1) -> INT1
#| base::bitwOr : (a:dbl, b:dbl) -> INT
#| base::bitwOr : (a:dbl1, b:dbl1) -> INT1
#| base::bitwXor : (a:dbl, b:dbl) -> INT
#| base::bitwXor : (a:dbl1, b:dbl1) -> INT1

#| base::bitwShiftL : (a:dbl, n:dbl1) -> INT
#| base::bitwShiftL : (a:dbl1, n:dbl1) -> INT1
#| base::bitwShiftR : (a:dbl, n:dbl1) -> INT
#| base::bitwShiftR : (a:dbl1, n:dbl1) -> INT1

# ========== Strings ==========

#| base::paste : (...: any, sep:chr1?, collapse:chr1?) -> CHR1
