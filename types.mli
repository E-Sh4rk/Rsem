
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
(*
val unary (-) : ( arg:v['n](dbl | 'n & (dbl \ ^dbl)) ) -> v['n](dbl | 'n & (dbl \ ^dbl))
val unary (+) : ( arg:v['n](dbl | 'n & (dbl \ ^dbl)) ) -> v['n](dbl | 'n & (dbl \ ^dbl))
val binary (+) : ( arg1:v['n](dbl | 'n & (dbl \ ^dbl)), arg2:v['n](dbl | 'n & (dbl \ ^dbl)) ) -> v['n](dbl | 'n & (dbl \ ^dbl))
val binary (-) : ( arg1:v['n](dbl | 'n & (dbl \ ^dbl)), arg2:v['n](dbl | 'n & (dbl \ ^dbl)) ) -> v['n](dbl | 'n & (dbl \ ^dbl))
*)
val c : ( ; v('p) ) -> v('p)<>
