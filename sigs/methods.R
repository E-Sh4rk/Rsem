# Signatures of R's `methods` package: S4 classes, generics and methods. Same
# format and conventions as base.R, in the `methods` namespace: R attaches
# methods at startup, so its names are looked up after those of `stats` and
# `utils` (cf. `search_path` in lang/metaEnv.ml), and a package can also call
# them qualified (`methods::new`).
#
# An S4 object is typed as a value whose classes start with its class, and its
# slots are its attributes, as they are in R. The classes, slots and methods a
# package defines are not known here: only what the functions do whatever the
# class is. The functions are the ones packages call (measured on 1000 CRAN
# packages).

# ========== Slots ==========

# The slot `name` of `object`: `object@name` is `@`(object, "name"), so the
# slot is selected by a literal name, as an attribute is (cf. `attr` in base.R).
#| base::(@) : (object:any with { #k:'a, any }, name: #k) -> 'a
#| base::(@<-) : (object:'a<`c> with { #k:any?, `r }, name: #k, v:'b) -> 'a<`c> with { #k:'b, `r }
# The same with the name as a string, which may not be a literal.
#| methods::slot : (object:any with { #k:'a, any }, name: #k, check:lgl1?) -> 'a
#| methods::slot : (object:any, name:CHR1, check:lgl1?) -> any
#| methods::slot<- : (object:'a<`c> with { #k:any?, `r }, name: #k, check:lgl1?, v:'b) -> 'a<`c> with { #k:'b, `r }
#| methods::slot<- : (object:'a<`c>, name:CHR1, check:lgl1?, v:any) -> 'a<`c>
#| methods::slotNames : (x:any) -> CHR<>

# ========== Objects ==========

# A new object of the class `Class`: with a literal class (the label variable
# `#c` stands for it), of that class. Its slots are the named arguments, but
# their types are not known here.
#| methods::new : (Class:#c, ...: any) -> <#c, ...>
#| methods::new : (Class:CHR1, ...: any) -> any
# The method `initialize` of the class: `.Object` with its slots set.
#| methods::initialize : (.Object:'a, ...: any) -> 'a
# Checks the validity of `object`: returns it (invisibly), or fails. With
# `test = TRUE`, the description of what is invalid instead of failing.
#| methods::validObject : (object:'a, test:ff?, complete:lgl1?) -> 'a
#| methods::validObject : (object:any, test:tt, complete:lgl1?) -> tt<> | CHR<>
# Whether `object` is of the class `class2`, or, without it, the classes
# `object` is (and extends). A literal `class2` narrows `object`, as for
# `inherits` (only its S3 classes are tracked).
#| methods::is : (object:any, class2:CHR1) -> LGL1<>
#| methods::is : (object:any, class2:absent) -> CHR<>
#| methods::is : (object:<#c, ...>, class2:#c) -> tt<>
#| methods::is : (object:<~#c, ...>, class2:#c) -> ff<>
# Whether `class1` extends `class2`, or, without it, the classes it extends.
#| methods::extends : (class1:any, class2:CHR1, maybe:lgl1?, fullInfo:lgl1?) -> LGL1<>
#| methods::extends : (class1:any, class2:absent, maybe:lgl1?, fullInfo:lgl1?) -> CHR<>
# `object` coerced to the class `Class`: for the basic classes, a vector of that
# type; otherwise, nothing is known of the result.
#| methods::as : (object:any, Class:"numeric", strict:lgl1?, ext:any?) -> DBL
#| methods::as : (object:any, Class:"double", strict:lgl1?, ext:any?) -> DBL
#| methods::as : (object:any, Class:"integer", strict:lgl1?, ext:any?) -> INT
#| methods::as : (object:any, Class:"character", strict:lgl1?, ext:any?) -> CHR
#| methods::as : (object:any, Class:"logical", strict:lgl1?, ext:any?) -> LGL
#| methods::as : (object:any, Class:"list", strict:lgl1?, ext:any?) -> list
#| methods::as : (object:any, Class:CHR1, strict:lgl1?, ext:any?) -> dyn

# ========== Dispatch ==========

# The body of an S4 generic dispatches to its methods, and a method to the next
# one: nothing is known of what they return.
#| methods::standardGeneric : (f:CHR1, fdef:any?) -> dyn
#| methods::callNextMethod : (...: any) -> dyn
# The default method of `show` prints `object`; `NULL` (invisibly).
#| methods::show : (object:any) -> null
#| methods::isGeneric : (f:CHR1, where:any?, fdef:any?, getName:lgl1?) -> LGL1<>
#| methods::existsMethod : (f:CHR1, signature:CHR?, where:any?) -> LGL1<>
#| methods::hasMethod : (f:CHR1, signature:CHR?, where:any?) -> LGL1<>
#| methods::isVirtualClass : (Class:CHR1, formal:lgl1?, where:any?) -> LGL1<>
#| methods::getMethod : (f:CHR1, signature:CHR?, where:any?, optional:lgl1?, mlist:any?, fdef:any?) -> dyn
#| methods::selectMethod : (f:CHR1, signature:CHR?, optional:lgl1?, useInherited:any?, mlist:any?, fdef:any?, verbose:lgl1?, doCache:lgl1?) -> dyn

# ========== Definitions ==========

# These define classes, generics and methods, at the top level of a package.
# The classes, slots and methods they define are not tracked here, only the
# values they return.

# Defines the class `Class`, and returns its generator, which builds objects of
# that class. Their type is not known here: a label variable (for a literal
# class) cannot occur in the result of the generator, an arrow inside the
# result.
#| methods::setClass : (Class:CHR1, representation:any?, prototype:any?, contains:CHR?, validity:any?, access:any?, where:any?, version:any?, sealed:lgl1?, package:CHR1?, S3methods:lgl1?, slots:any?) -> (...: any) -> any
# The slots (and superclasses) of a class, for `setClass`.
#| methods::representation : (...: any) -> list
# The classes of the arguments a method is for, for `setMethod`.
#| methods::signature : (...: chr) -> CHR<>
# The default values of the slots of a class, for `setClass`.
#| methods::prototype : (...: any) -> any
# Defines the S4 generic `name`, and returns `name` (invisibly).
#| methods::setGeneric : (name:CHR1, def:any?, where:any?, package:any?, valueClass:any?, useAsDefault:any?, genericFunction:any?, group:any?, signature:CHR?, simpleInheritanceOnly:any?) -> CHR1<>
# Defines a method of the S4 generic `f`, and returns `f` (invisibly).
#| methods::setMethod : (f:CHR1, signature:any?, definition:any?, where:any?, valueClass:any?, sealed:lgl1?) -> CHR1<>
# Sets the validity method of the class `Class`; its definition (invisibly).
#| methods::setValidity : (Class:CHR1, method:any, where:any?) -> any
# Defines the class `name` as the union of `members`; its generator.
#| methods::setClassUnion : (name:CHR1, members:CHR?, where:any?) -> any
# Registers S3 classes, so that S4 signatures can use them.
#| methods::setOldClass : (Classes:CHR, prototype:any?, where:any?, test:lgl1?, S4Class:any?) -> null
# Defines how `as` coerces from the class `from` to the class `to`.
#| methods::setAs : (from:CHR1, to:CHR1, def:any, replace:any?, where:any?) -> null
# Defines a reference class; its generator, an object whose `$new` builds
# objects of the class.
#| methods::setRefClass : (Class:CHR1, fields:any?, contains:any?, methods:any?, where:any?, inheritPackage:lgl1?, ...: any) -> dyn
