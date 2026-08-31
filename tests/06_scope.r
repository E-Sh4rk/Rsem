# ========== Scopes of top-level expressions ==========

# A brace is not a scope in R -- `{` evaluates its arguments in the environment
# it is itself evaluated in -- so `u` is a top-level definition just as much as
# `blk`, and is visible afterwards. It needs no declaration: like a variable
# local to a function, it is assigned once and the assignment gives its type.
blk <- { u <- 1 ; u }
use_u <- function() u

# The same for an assignment nested in a top-level `if` or `for`.
if (1 > 0) { z <- 1 } else { z <- 2 }
use_z <- function() z

# The loop variable of a top-level `for` persists after it, as it does in R.
for (i in 1:2) { w <- i }
use_w <- function() w
use_i <- function() i

# Reading a hoisted name back gives the type it was written with joined with
# the content its cell was created holding -- a variable nothing constrains --
# so the free variables are bottom-instantiated. That has to respect polarity
# and cover row variables, which is [TVOp.bot_instance]'s job: a record keeps
# both branches, and a function, whose own variable occurs in both polarities
# and so survives, is generalized exactly as a plain definition would be.
if (1 > 0) { r <- list(a = 1) } else { r <- list(b = 2) }
use_r <- function() r

if (1 > 0) { g <- function(x) x }
use_g <- function() g(1)

# A declared name keeps the type its declaration gives it, and stays mutable.
#| au : dbl
ablk <- { au <- 1 ; au }

# `local`, unlike a brace, does evaluate its argument in a fresh environment,
# so what it assigns is scoped to the block. An inner name can be annotated,
# being an ordinary scoped local.
bundle <- local({
  #| helper : (a:dbl1) -> dbl1
  helper <- function(a) a + 1
  list(h = helper)
})
use_bundle <- function() bundle$h(1)

# The block's names do not escape it: `helper` is unbound here.
leaked <- function() helper

# `local` together with `<<-`, the counter idiom: the block's names are
# mutable locals, so the closure it returns can assign them.
counter <- local({
  #| n : dbl1
  n <- 0
  function() { n <<- n + 1 ; n }
})

# A package defining its own `local` gets an ordinary call, so what the braces
# assign binds in the enclosing scope -- here, at top level. What decides it is
# the scope, in `bv_e` as much as in `aux_e`: were the two to disagree, `d`
# would be bound by neither and the assignment would reach further out.
local <- function(e) e
shadowed <- local({ d <- 2 ; d })
use_d <- function() d

# The same where `local` is shadowed by a binding of the enclosing body, which
# shadows it over the whole of that body rather than from its assignment on.
shadow_fn <- function() {
  y <- local({ e <- 3 ; e })
  local <- function(v) v
  e
}
