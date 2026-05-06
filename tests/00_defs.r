
## num1 = int1 | dbl1
## num = int | dbl

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

## ([[]]) : (lst:{ 'a}, k:num|chr) -> 'a|null
## ([[]]) : (lst:{ #k:'a, any }, k=#k) -> 'a
## ([[]]<-) : (lst:{ 'a}, k:num|chr, v:'b) -> { 'a|'b}
## ([[]]<-) : (lst:{ #k:any?, `r}, k=#k, v:'b) -> { #k:'b, `r}

# ========== Classes ==========

## class : (x:'a<...>) -> ^chr
## class<- : (x:'a<...> , c:^chr) -> 'a<...>
## unclass : (x:'a<...>) -> 'a<>
