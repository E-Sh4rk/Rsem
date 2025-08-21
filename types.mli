
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
val unary (-) : { v['n](dbl) ..} -> v['n](dbl)
val unary (+) : { v['n](dbl) ..} -> v['n](dbl)
val binary (+) : { v[any](dbl) ; v[any](dbl) ..} -> v[any](dbl)
val binary (-) : { v[any](dbl) ; v[any](dbl) ..} -> v[any](dbl)
val c : { ...(v<'na>[any]('p)) ..} -> v<'na>[any]('p)
