
## num1 = int1 | dbl1
## num = int | dbl

## print : ( arg:'a ) -> 'a

# (-) : ( arg:v['n](^dbl | 'x & dbl) ) -> v['n](^dbl | 'x & dbl)
# (+) : ( arg:v['n](^dbl | 'x & dbl) ) -> v['n](^dbl | 'x & dbl)
# (+) : ( arg1:v['n](^dbl | 'x & dbl), arg2:v['n](^dbl | 'x & dbl) ) -> v['n](^dbl | 'x & dbl)
# (-) : ( arg1:v['n](^dbl | 'x & dbl), arg2:v['n](^dbl | 'x & dbl) ) -> v['n](^dbl | 'x & dbl)
# (-) : (( arg:^dbl['n] ) -> ^dbl['n]) & (( arg:dbl['n] ) -> dbl['n])
# (+) : (( arg:^dbl['n] ) -> ^dbl['n]) & (( arg:dbl['n] ) -> dbl['n])
# (+) : (( arg1:^dbl['n], arg2:^dbl['n] ) -> ^dbl['n]) & (( arg1:dbl['n], arg2:dbl['n] ) -> dbl['n])
# (-) : (( arg1:^dbl['n], arg2:^dbl['n] ) -> ^dbl['n]) & (( arg1:dbl['n], arg2:dbl['n] ) -> dbl['n])

## (-) : ( arg:dbl['n] ) -> dbl['n]
## (-) : ( arg1:dbl['n], arg2:dbl['n] ) -> dbl['n]
## (+) : ( arg:dbl['n] ) -> dbl['n]
## (+) : ( arg1:dbl['n], arg2:dbl['n] ) -> dbl['n]
## c : ( ; v('p) ) -> v('p)<>

## typeof : (( arg: dbl ) -> v1(^"double")) & (( arg: chr ) -> v1(^"character"))
## typeof : (( arg: lgl ) -> v1(^"logical")) & (( arg: int ) -> v1(^"integer"))
## typeof : (( arg: clx ) -> v1(^"complex")) & (( arg: raw ) -> v1(^"raw"))
## typeof : (( arg: list ) -> v1(^"list")) & (( arg: null ) -> v1(^"NULL"))
## fail : empty -> any

# ========== Lists ==========

## list : ( ; `r ) -> { ; `r }
## ([[]]) : (lst:{ ; 'a}, k:num|chr) -> 'a|null
## ([[]]) : (lst:{ #k:'a ...}, k:#k) -> 'a
## ($) : (lst:{ #k:'a ...}, k:#k) -> 'a
## ($<-) : (lst:{ #k:any? ; `r}, k:#k, v:'b) -> { #k:'b ; `r}
## ([[]]<-) : (lst:{ ; 'a}, k:num|chr, v:'b) -> { ; 'a|'b}
## ([[]]<-) : (lst:{ #k:any? ; `r}, k:#k, v:'b) -> { #k:'b ; `r}

# ========== Classes ==========

## class<- : (x:'a<...> , c:^chr) -> 'a<...>
## class : (x:'a<...>) -> ^chr
