
# Comment :!:!:!: EndComment

print("Hello World!")
print(42)
print(TRUE)

-42
+42
42 + 24

c(print(42), print(FALSE))

i <- 42

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
        fail("invalid input")
    }
    # return(t)
}