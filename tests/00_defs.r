## print : ( x:'a ) -> 'a
## c : ( ...: v('p) ) -> v('p)<>

## (:) : ( from:dbl, to:dbl ) -> dbl

## (-) : ( x:v('a)&dbl ) -> v('a)&dbl
## (-) : ( x:dbl1 ) -> dbl1
## (-) : ( x:v('a)&dbl, y:v('a)&dbl) -> v('a)&dbl
## (-) : ( x:dbl1, y:dbl1) -> dbl1

## (+) : ( x:v('a)&dbl ) -> v('a)&dbl
## (+) : ( x:dbl1 ) -> dbl1
## (+) : ( x:v('a)&dbl, y:v('a)&dbl) -> v('a)&dbl
## (+) : ( x:dbl1, y:dbl1) -> dbl1

## (*) : ( x:v('a)&dbl, y:v('a)&dbl) -> v('a)&dbl
## (*) : ( x:dbl1, y:dbl1) -> dbl1
## (/) : ( x:v('a)&dbl, y:v('a)&dbl) -> v('a)&dbl
## (/) : ( x:dbl1, y:dbl1) -> dbl1
## (%/%) : ( x:int, y:int ) -> int
## (%/%) : ( x:int1, y:int1 ) -> int1
## (%%) : ( x:v('a)&dbl, y:v('a)&dbl) -> v('a)&dbl
## (%%) : ( x:dbl1, y:dbl1) -> dbl1

## (<) : ( x:dbl1, y:dbl1 ) -> lgl1<>
## (<) : ( x:dbl, y:dbl ) -> lgl<>
## (<=) : ( x:dbl1, y:dbl1 ) -> lgl1<>
## (<=) : ( x:dbl, y:dbl ) -> lgl<>
## (>) : ( x:dbl1, y:dbl1 ) -> lgl1<>
## (>) : ( x:dbl, y:dbl ) -> lgl<>
## (>=) : ( x:dbl1, y:dbl1 ) -> lgl1<>
## (>=) : ( x:dbl, y:dbl ) -> lgl<>

## typeof : (( x: DBL ) -> "double") & (( x: CHR ) -> "character")
## typeof : (( x: LGL ) -> "logical") & (( x: INT ) -> "integer")
## typeof : (( x: CLX ) -> "complex") & (( x: RAW ) -> "raw")
## typeof : (( x: list ) -> "list") & (( x: null ) -> "NULL")
## fail : empty -> any

## lapply : (X:v('a), FUN:@(v1('a), X:absent, FUN:absent, ...: `r) -> 'b, ...: `r) -> {'b}
## lapply : (X:{'a}, FUN:@('a, X:absent, FUN:absent, ...: `r) -> 'b, ...: `r) -> {'b}

# ========== Lists ==========

## list : ( ...: 'a ) -> { 'a }
## list : ( ...: `r ) -> { `r }

## ($) : (lst:{ #k:'a, any}, k=#k) -> 'a
## ($<-) : (lst:{ #k:any?, `r}, k=#k, v:'b) -> { #k:'b, `r}

## ([[]]) : (lst:v('a), ...: dbl) -> v('a)
## ([[]]) : (lst:{ 'a}, ...: chr) -> 'a|null
## ([[]]) : (lst:{ #k:'a, any }, k=#k) -> 'a
## ([[]]<-) : (lst:v('a), ...: dbl, v:v('a)) -> v('a)
## ([[]]<-) : (lst:{ 'a}, ...: chr, v:'b) -> { 'a|'b}
## ([[]]<-) : (lst:{ #k:any?, `r}, k=#k, v:'b) -> { #k:'b, `r}

# ========== Classes ==========

## class : (x:'a<...>) -> chr
## class<- : (x:'a<...> , v:chr) -> 'a<...>
## unclass : (x:'a<...>) -> 'a<>

# ========== Vectors and matrices ==========

## vector : (mode: "logical"?, length: dbl?) -> lgl
## vector : (mode: "numeric", length: dbl?) -> dbl
## vector : (mode: "character", length: dbl?) -> chr
## vector : (mode: "raw", length: dbl?) -> raw
## vector : (mode: "list", length: dbl?) -> { null }

## matrix : (data: absent, nrow: dbl?, ncol: dbl?) -> lgl
## matrix : (data: v1('a), nrow: dbl?, ncol: dbl?) -> v('a)

# ========== Bitwise ==========

## bitwNot : (a:dbl) -> INT
## bitwNot : (a:dbl1) -> INT1

## bitwAnd : (a:dbl, b:dbl) -> INT
## bitwAnd : (a:dbl1, b:dbl1) -> INT1
## bitwOr : (a:dbl, b:dbl) -> INT
## bitwOr : (a:dbl1, b:dbl1) -> INT1
## bitwXor : (a:dbl, b:dbl) -> INT
## bitwXor : (a:dbl1, b:dbl1) -> INT1

## bitwShiftL : (a:dbl, n:dbl1) -> INT
## bitwShiftL : (a:dbl1, n:dbl1) -> INT1
## bitwShiftR : (a:dbl, n:dbl1) -> INT
## bitwShiftR : (a:dbl1, n:dbl1) -> INT1
