
type num1 = int1 | dbl1
type num = int | dbl

val print : ( arg:'a ) -> 'a
(* val unary (-) : ( arg:v['n](^dbl | 'x & dbl) ) -> v['n](^dbl | 'x & dbl)
val unary (+) : ( arg:v['n](^dbl | 'x & dbl) ) -> v['n](^dbl | 'x & dbl)
val binary (+) : ( arg1:v['n](^dbl | 'x & dbl), arg2:v['n](^dbl | 'x & dbl) ) -> v['n](^dbl | 'x & dbl)
val binary (-) : ( arg1:v['n](^dbl | 'x & dbl), arg2:v['n](^dbl | 'x & dbl) ) -> v['n](^dbl | 'x & dbl) *)
(* val unary (-) : (( arg:^dbl['n] ) -> ^dbl['n]) & (( arg:dbl['n] ) -> dbl['n])
val unary (+) : (( arg:^dbl['n] ) -> ^dbl['n]) & (( arg:dbl['n] ) -> dbl['n])
val binary (+) : (( arg1:^dbl['n], arg2:^dbl['n] ) -> ^dbl['n]) & (( arg1:dbl['n], arg2:dbl['n] ) -> dbl['n])
val binary (-) : (( arg1:^dbl['n], arg2:^dbl['n] ) -> ^dbl['n]) & (( arg1:dbl['n], arg2:dbl['n] ) -> dbl['n]) *)
val unary (-) : ( arg:dbl['n] ) -> dbl['n]
val unary (+) : ( arg:dbl['n] ) -> dbl['n]
val binary (+) : ( arg1:dbl['n], arg2:dbl['n] ) -> dbl['n]
val binary (-) : ( arg1:dbl['n], arg2:dbl['n] ) -> dbl['n]
val c : ( ; v('p) ) -> v('p)<>

val typeof : (( arg: dbl ) -> v1(^"double")) & (( arg: chr ) -> v1(^"character")) \
           & (( arg: lgl ) -> v1(^"logical")) & (( arg: int ) -> v1(^"integer")) \
           & (( arg: clx ) -> v1(^"complex")) & (( arg: raw ) -> v1(^"raw")) \
           & (( arg: list ) -> v1(^"list")) & (( arg: null ) -> v1(^"NULL"))
val fail : empty -> any


(* ===== Lists ===== *)

val list : ( ; `r ) -> { ; `r }
