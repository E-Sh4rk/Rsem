
## num1 = int1 | dbl1
## num = int | dbl

## print : ( x:'a ) -> 'a
## c : ( ; v('p) ) -> v('p)<>

## (-) : ( x:dbl['n] ) -> dbl['n]
## (-) : ( x:dbl['n], y:dbl['n] ) -> dbl['n]
## (+) : ( x:dbl['n] ) -> dbl['n]
## (+) : ( x:dbl['n], y:dbl['n] ) -> dbl['n]

## typeof : (( x: dbl ) -> v1(^"double")) & (( x: chr ) -> v1(^"character"))
## typeof : (( x: lgl ) -> v1(^"logical")) & (( x: int ) -> v1(^"integer"))
## typeof : (( x: clx ) -> v1(^"complex")) & (( x: raw ) -> v1(^"raw"))
## typeof : (( x: list ) -> v1(^"list")) & (( x: null ) -> v1(^"NULL"))
## fail : empty -> any

# ========== Lists ==========

## list : ( ; `r ) -> { ; `r }

## ($) : (lst:{ #k:'a ...}, k:#k) -> 'a
## ($<-) : (lst:{ #k:any? ; `r}, k:#k, v:'b) -> { #k:'b ; `r}

## ([[]]) : (lst:{ ; 'a}, k:num|chr) -> 'a|null
## ([[]]) : (lst:{ #k:'a ...}, k:#k) -> 'a
## ([[]]<-) : (lst:{ ; 'a}, k:num|chr, v:'b) -> { ; 'a|'b}
## ([[]]<-) : (lst:{ #k:any? ; `r}, k:#k, v:'b) -> { #k:'b ; `r}

# ========== Classes ==========

## class : (x:'a<...>) -> ^chr
## class<- : (x:'a<...> , c:^chr) -> 'a<...>
