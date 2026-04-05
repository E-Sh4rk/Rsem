
print("Hello World!")
print(42)
print(TRUE)

-42
+42
42 + 24

c(print(42), print(FALSE))

int <- 42L
dbl <- 42
clx <- 42i

## num1 : num1
num1 <- 42

f <- function(a){
  if (a > 0) {
    a
  }
  else {
    -a
  }
}

f <- function(a=42){
  if (a > 0) {
    a
  }
  else {
    -a
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

## ret_ann : (x:any) -> lgl1
## ret_ann : (x:null) -> v1(^ff)
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
  list(l[[1]],l$a,l$b)
}

test_classes <- function(x) {
  unclass(x)
  class(x) <- c("abc", "def")
  class(x)
}

test_attr <- function(x) {
  attributes(x) <- list(a=42)
  attr(x,"dim") <- c(2,5)
  x
}