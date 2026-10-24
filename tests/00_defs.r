# Helpers of the tests. They are not R functions, so they are declared as
# global names (the signatures of base R live in ../sigs/base.R, which is
# processed before the tests).

#| isTrue : (x:lgl , na: lgl1?) -> LGL<>
#| isTrue : (x:tt , na: lgl1?) -> tt<>
#| isTrue : (x:ff , na: lgl1?) -> ff<>

#| isFalse : (x:lgl , na: lgl1?) -> LGL<>
#| isFalse : (x:tt , na: lgl1?) -> ff<>
#| isFalse : (x:ff , na: lgl1?) -> tt<>

#| fail : empty -> any
#| exit : any -> empty
