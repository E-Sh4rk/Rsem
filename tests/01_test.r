
print("Hello World!")
print(42)
print(TRUE)

-42
+42
42 + 24

c(print(42), print(FALSE))
c(, print(42), , print(FALSE), )

int <- 42L
dbl <- 42
clx <- 42i

#| num1 : dbl1
num1 <- 42

f_succ <- function(a) a + 1
f_succ_succ <- function(a) f_succ(f_succ(a))

f_req <- function(a){
  if (a > 0) {
    a
  }
  else {
    -a
  }
}

f_opt <- function(a=42){
  if (a > 0) {
    a
  }
  else {
    (-a)
  }
}

#| f_opt_ann : ( a: dbl ) -> dbl
#| f_opt_ann : ( a: null? ) -> lgl1
f_opt_ann <- function(a=NULL){
  if (a == NULL) {
    FALSE
  }
  else {
    a
  }
}

app <- function(){
  f <- function(b=12){ b }
  f(TRUE)
}

ret <- function(x) {
  if (x == NULL)
    return(FALSE)
  if (x == FALSE)
    return(FALSE)
  if (x == 0)
    return(FALSE)
  return(TRUE)
}

#| ret_ann : (x:any) -> lgl1
#| ret_ann : (x:null) -> ff
ret_ann <- function(x) {
  if (x == NULL)
    return(FALSE)
  if (x == FALSE)
    return(FALSE)
  if (x == 0)
    return(FALSE)
  return(TRUE)
}

narrowing <- function(x) {
  if (x == NULL)
    return(NULL)
  return(-x)
}

#| narrowing_ann : ( x: dbl ) -> dbl
#| narrowing_ann : ( x: null ) -> null
narrowing_ann <- function(x) {
  if (x == NULL)
    return(NULL)
  return(-x)
}

#| narrowing_ann2 : ( x: dbl|null ) -> dbl|null
narrowing_ann2 <- function(x) {
  if (x == NULL)
    return(NULL)
  return(-x)
}

loop_break <- function(x) {
  i <- x
  while (i != NULL) {
    if (i > 100) break
    print(i)
    i <- i + 1
    next
  }
  i
}

cases <- function(x) {
  t <- typeof(x)
  if (t == "double") {
    return(0)
  }
  else {
    fail("")
  }
}

assign <- function(x) {
  g <- function() {
    x <- 42
  }
  g()
  x
}
superassign <- function(x) {
  g <- function() {
    x <<- 42
  }
  g()
  x
}

list()
list(42)
list(aa = 42)

test_lists <- function() {
  l <- list(42, a=42L)
  l$b <- FALSE
  l[["a"]] <- "a"
  list(one=l[[1]],a=l$a,b=l$b)
}

#| nested_list : (x: { a : { lgl1 }, `r} ) -> { a : { lgl1 }, `r}
nested_list <- function(x) {
  x$a[[1]] <- FALSE
  # x <- $<-(x, a, [[]]<-(x$a, 1, FALSE))
  x
}

test_lists_sym <- function() {
  l <- list(a=42L,b=TRUE)
  a <- identity("a")
  l[[a]]
}

test_classes <- function(x) {
  x <- unclass(x)
  class(x) <- c("abc", "def")
  class(x) <- class(x)
  x
}

# test_attr <- function(x) {
#   attributes(x) <- list(a=42)
#   attr(x,"dim") <- c(2,5)
#   x
# }

dots_encoding <- function(...) {
  return(...)
}

#| test_dots1 : (...:`r) -> {`r}
test_dots1 <- function(...) {
  return(list(...))
}

#| test_dots2 : (...:'a) -> {'a}
test_dots2 <- function(...) {
  return(list(...))
}

test_dots3 <- function(...) {
  return(list(..1))
}
