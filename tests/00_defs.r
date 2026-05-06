
## num1 = lgl1 | int1 | dbl1
## num = lgl | int | dbl

## print : ( x:'a ) -> 'a
## c : ( ; v('p) ) -> v('p)<>

## (:) : ( from:num, to:num ) -> num

## (-) : ( x:dbl['n] ) -> dbl['n]
## (-) : ( x:dbl['n], y:dbl['n] ) -> dbl['n]
## (+) : ( x:dbl['n] ) -> dbl['n]
## (+) : ( x:dbl['n], y:dbl['n] ) -> dbl['n]

## (<) : ( x:num1, y:num1 ) -> lgl1<>
## (<) : ( x:num, y:num ) -> lgl<>
## (<=) : ( x:num1, y:num1 ) -> lgl1<>
## (<=) : ( x:num, y:num ) -> lgl<>
## (>) : ( x:num1, y:num1 ) -> lgl1<>
## (>) : ( x:num, y:num ) -> lgl<>
## (>=) : ( x:num1, y:num1 ) -> lgl1<>
## (>=) : ( x:num, y:num ) -> lgl<>

## typeof : (( x: dbl ) -> "double") & (( x: chr ) -> "character")
## typeof : (( x: lgl ) -> "logical") & (( x: int ) -> "integer")
## typeof : (( x: clx ) -> "complex") & (( x: raw ) -> "raw")
## typeof : (( x: list ) -> "list") & (( x: null ) -> "NULL")
## fail : empty -> any

# ========== Lists ==========

## list : ( ; 'a ) -> { 'a }
## list : ( ; absent, `r ) -> { `r }

## ($) : (lst:{ #k:'a, any}, k=#k) -> 'a
## ($<-) : (lst:{ #k:any?, `r}, k=#k, v:'b) -> { #k:'b, `r}

## ([[]]) : (lst:v('a) ; num) -> v('a)
## ([[]]) : (lst:{ 'a} ; num|chr) -> 'a|null
## ([[]]) : (lst:{ #k:'a, any }, k=#k) -> 'a
## ([[]]<-) : (lst:v('a) ; num ; v:v('a)) -> v('a)
## ([[]]<-) : (lst:{ 'a} ; num|chr ; v:'b) -> { 'a|'b}
## ([[]]<-) : (lst:{ #k:any?, `r}, k=#k, v:'b) -> { #k:'b, `r}

# ========== Classes ==========

## class : (x:'a<...>) -> ^chr
## class<- : (x:'a<...> , v:^chr) -> 'a<...>
## unclass : (x:'a<...>) -> 'a<>

# ========== Vectors and matrices ==========

## vector : (mode: "logical"?, length: num?) -> lgl
## vector : (mode: "numeric", length: num?) -> dbl
## vector : (mode: "character", length: num?) -> chr
## vector : (mode: "raw", length: num?) -> raw
## vector : (mode: "list", length: num?) -> { null }

## matrix : (data: absent, nrow: num?, ncol: num?) -> lgl
## matrix : (data: v1('a), nrow: num?, ncol: num?) -> v('a)
