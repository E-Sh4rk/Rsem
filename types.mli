
(* val print : { 'a ..} -> 'a
val unary (-) : { DBL ..} -> DBL
val unary (+) : { DBL ..} -> DBL
val binary (+) : { DBL ; DBL ..} -> DBL
val binary (-) : { DBL ; DBL ..} -> DBL
val c :
    ({ ...(INT?) ..} -> INT?) &
    ({ ...(LGL?) ..} -> LGL?) &
    ({ ...(DBL?) ..} -> DBL?) &
    ({ ...(CLX?) ..} -> CLX?) &
    ({ ...(CHR?) ..} -> CHR?) &
    ({ ...(RAW?) ..} -> RAW?) &
    ({ ...(VEC) ..} -> VEC) *)

val print : ( arg:'a ) -> 'a
(* val unary (-) : ( arg:v['n](^dbl | 'x & dbl) ) -> v['n](^dbl | 'x & dbl)
val unary (+) : ( arg:v['n](^dbl | 'x & dbl) ) -> v['n](^dbl | 'x & dbl)
val binary (+) : ( arg1:v['n](^dbl | 'x & dbl), arg2:v['n](^dbl | 'x & dbl) ) -> v['n](^dbl | 'x & dbl)
val binary (-) : ( arg1:v['n](^dbl | 'x & dbl), arg2:v['n](^dbl | 'x & dbl) ) -> v['n](^dbl | 'x & dbl) *)
val unary (-) : (( arg:^dbl['n] ) -> ^dbl['n]) & (( arg:dbl['n] ) -> dbl['n])
val unary (+) : (( arg:^dbl['n] ) -> ^dbl['n]) & (( arg:dbl['n] ) -> dbl['n])
val binary (+) : (( arg1:^dbl['n], arg2:^dbl['n] ) -> ^dbl['n]) & (( arg1:dbl['n], arg2:dbl['n] ) -> dbl['n])
val binary (-) : (( arg1:^dbl['n], arg2:^dbl['n] ) -> ^dbl['n]) & (( arg1:dbl['n], arg2:dbl['n] ) -> dbl['n])
val c : ( ; v('p) ) -> v('p)<>
