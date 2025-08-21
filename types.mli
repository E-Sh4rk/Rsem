
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

val print : { 'a ..} -> 'a
val unary (-) : { v<'na>['n](dbl) ..} -> v<'na>['n](dbl)
val unary (+) : { v<'na>['n](dbl) ..} -> v<'na>['n](dbl)
val binary (+) : { v<'na>[any](dbl) ; v<'na>[any](dbl) ..} -> v<'na>[any](dbl)
val binary (-) : { v<'na>[any](dbl) ; v<'na>[any](dbl) ..} -> v<'na>[any](dbl)
val c : { ...(v<'na>[any]('p)) ..} -> v<'na>[any]('p)
