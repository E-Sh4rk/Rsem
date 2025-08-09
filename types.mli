
val print : { 'a ..} -> 'a
val unary (-) : { DBL ..} -> DBL
val unary (+) : { DBL ..} -> DBL
val binary (+) : { DBL ; DBL ..} -> DBL
val binary (-) : { DBL ; DBL ..} -> DBL
val c :
    ({ ... : INT? ..} -> INT?) &
    ({ ... : LGL? ..} -> LGL?) &
    ({ ... : DBL? ..} -> DBL?) &
    ({ ... : CLX? ..} -> CLX?) &
    ({ ... : CHR? ..} -> CHR?) &
    ({ ... : RAW? ..} -> RAW?) &
    ({ ... : VEC ..} -> VEC)
