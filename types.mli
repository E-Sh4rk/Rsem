
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

val typeof : (( arg: dbl ) -> v(^"double")) & (( arg: chr ) -> v(^"character")) \
           & (( arg: lgl ) -> v(^"logical")) & (( arg: int ) -> v(^"integer")) \
           & (( arg: clx ) -> v(^"complex")) & (( arg: raw ) -> v(^"raw")) \
           & (( arg: list ) -> v(^"list")) & (( arg: null ) -> v(^"NULL"))
val fail : empty -> any