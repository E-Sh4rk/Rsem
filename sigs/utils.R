# Signatures of R's `utils` package. Same format and conventions as base.R, in
# the `utils` namespace: R attaches utils at startup, so its names are looked
# up after those of `stats` (cf. `search_path` in lang/metaEnv.ml), and a
# package can also call them qualified (`utils::head`).
#
# The functions are the ones packages call (measured on the dashboard's
# packages and a hundred CRAN ones).

# ========== Parts of vectors and lists ==========

# The first (last) `n` elements. `head` and `tail` are generic: data frames
# and matrices have methods that keep their class and dimensions, which the
# vector and list overloads do not describe.
#| utils::head : (x:v('a), n:dbl1?, ...: any) -> v('a)
#| utils::head : (x:{'a}, n:dbl1?, ...: any) -> {'a}
#| utils::head : (x:null, n:dbl1?, ...: any) -> null
#| utils::tail : (x:v('a), n:dbl1?, ...: any) -> v('a)
#| utils::tail : (x:{'a}, n:dbl1?, ...: any) -> {'a}
#| utils::tail : (x:null, n:dbl1?, ...: any) -> null

# Whether `x` has elements named `name`, one result per name.
#| utils::hasName : (x:any, name:chr1) -> LGL1<>
#|               && (x:any, name:chr) -> LGL<>

# `x` with the elements of `val` replacing (or added to) those of the same
# name, recursively for the lists in both; an element of `val` that is `NULL`
# removes it.
#| utils::modifyList : (x:list, val:list, keep.null:lgl1?) -> { any }

# The combinations of `m` elements of `x` (of `seq_len(x)` when `x` is a
# number), as the columns of a matrix; with `FUN`, its results, simplified as
# `sapply` would.
#| utils::combn : (x:v('a), m:dbl1, FUN:null?, simplify:tt?) -> (INT | v('a))<> with { dim: INT, any }
#| utils::combn : (x:vec, m:dbl1, FUN:any, simplify:lgl1?, ...: any) -> dyn

# Concatenates the vectors of a list (or the columns of a data frame) into
# one column, with the names of the vectors as a factor: generic.
#| utils::stack : (x:any, ...: any) -> dyn

# Converts the columns (or the strings) to the most specific type: generic.
#| utils::type.convert : (x:any, ...: any) -> dyn

# The edit distances between the strings of `x` and `y` (of `x`, without
# `y`), as a matrix.
#| utils::adist : (x:chr, y:chr|null?, ...: any) -> DBL<> with { dim: INT, any }

# ========== Input and output ==========

# A data frame read from a file (or a connection, or `text`).
#| utils::read.table : (file:any?, ...: any) -> { any }<data.frame> with { names: CHR, any }
#| utils::read.csv : (file:any, ...: any) -> { any }<data.frame> with { names: CHR, any }
#| utils::read.csv2 : (file:any, ...: any) -> { any }<data.frame> with { names: CHR, any }
#| utils::read.delim : (file:any, ...: any) -> { any }<data.frame> with { names: CHR, any }
# Writes a data frame (or a matrix) to a file; `NULL` (invisibly).
#| utils::write.table : (x:any, file:any?, ...: any) -> null
#| utils::write.csv : (x:any, file:any?, ...: any) -> null

# What the expressions print, one string per line; written to `file` instead
# (returning `NULL`) when there is one.
#| utils::capture.output : (...: any, file:null?, append:lgl1?, type:CHR?, split:lgl1?) -> CHR<>
#| utils::capture.output : (...: any, file:~null, append:lgl1?, type:CHR?, split:lgl1?) -> null

# Prints the structure of an object; `NULL` (invisibly).
#| utils::str : (object:any, ...: any) -> null

# Flushes the console's output.
#| utils::flush.console : () -> null

# A text progress bar, and its update (which returns the previous value,
# invisibly).
#| utils::txtProgressBar : (min:dbl1?, max:dbl1?, initial:dbl1?, char:chr1?, width:dbl1|null?, title:any?, label:any?, style:dbl1?, file:any?) -> { any }<txtProgressBar>
#| utils::setTxtProgressBar : (pb:any, value:dbl1, title:any?, label:any?) -> (DBL1 | INT1)<>
# `close` of a progress bar is a method of utils: it ends the bar.
#| base::close : (con:<txtProgressBar, ...>, ...: any) -> null

# ========== Files and URLs ==========

# The exit status of the download (0 for success).
#| utils::download.file : (url:CHR, destfile:CHR, method:CHR1?, quiet:lgl1?, mode:CHR1?, cacheOK:lgl1?, extra:any?, headers:any?, ...: any) -> INT1<>
# Archives: the status of `tar` and `zip`; the extracted files of `unzip` (or,
# with `list = TRUE`, a data frame of the files the archive holds).
#| utils::tar : (tarfile:any, files:CHR|null?, ...: any) -> INT1<>
#| utils::zip : (zipfile:CHR1, files:CHR, flags:chr1?, extras:chr?, zip:CHR1?) -> INT1<>
#| utils::unzip : (zipfile:CHR1, files:CHR|null?, list:ff?, ...: any) -> CHR<>
#| utils::unzip : (zipfile:CHR1, files:CHR|null?, list:tt, ...: any) -> { any }<data.frame> with { names: CHR, any }
# Percent-encodes the characters of the URLs.
#| utils::URLencode : (URL:CHR1, reserved:lgl1?, repeated:lgl1?) -> CHR1<>
#|                 && (URL:CHR, reserved:lgl1?, repeated:lgl1?) -> CHR<>
# The short (8.3) form of Windows paths.
#| utils::shortPathName : (path:chr1) -> CHR1<>
#|                     && (path:chr) -> CHR<>
# Opens files in an editor; `NULL` (invisibly).
#| utils::file.edit : (...: any) -> null

# ========== Packages and sessions ==========

# Declares names as global variables, for `R CMD check`; the names declared
# so far (invisibly).
#| utils::globalVariables : (names:chr?, package:any?, add:lgl1?) -> CHR<>
# The version of a package: a `package_version`, of which the comparisons and
# the conversions are methods (`packageVersion("x") >= "1.2"`), which the
# type says nothing about.
#| utils::packageVersion : (pkg:chr1, lib.loc:chr|null?) -> dyn
# The name of the package `env` belongs to (the calling one by default).
#| utils::packageName : (env:env?) -> CHR1<> | null
# The fields of a package's DESCRIPTION: a list of class `packageDescription`,
# a string with one field and `drop = TRUE`, or `NA` when not found.
#| utils::packageDescription : (pkg:chr1, lib.loc:chr|null?, fields:chr|null?, drop:lgl1?, encoding:any?) -> dyn
# The packages installed (available) as a matrix of strings, one row each.
#| utils::installed.packages : (...: any) -> CHR<> with { dim: INT, dimnames: list?, any }
#| utils::available.packages : (...: any) -> CHR<> with { dim: INT, dimnames: list?, any }
#| utils::install.packages : (...: any) -> null
# A bibliographic entry, and the citation of a package.
#| utils::bibentry : (...: any) -> { any }<bibentry>
#| utils::citation : (package:chr1?, lib.loc:chr|null?, auto:any?) -> { any }<citation, bibentry>
# The R session: the versions of R, of the platform and of the attached
# packages.
#| utils::sessionInfo : (...: any) -> { any }<sessionInfo>
# An object of a namespace, exported or not, of which the type says nothing.
#| utils::getFromNamespace : (x:CHR1, ns:any, pos:any?, envir:any?) -> dyn
# The memory an object uses, in bytes.
#| utils::object.size : (x:any) -> DBL1<object_size>
# Loads data sets into `envir`; the names of the data sets (invisibly).
#| utils::data : (...: any, list:CHR?, package:CHR|null?, lib.loc:chr|null?, verbose:lgl1?, envir:env?, overwrite:lgl1?) -> CHR<>
# Documentation, vignettes and demos, of which the type says nothing.
#| utils::help : (...: any) -> dyn
#| utils::vignette : (...: any) -> dyn
#| utils::demo : (...: any) -> dyn

# ========== Source references ==========

# Where a function (or a srcref) was defined: its file, and its lines (or
# columns), `NULL` when it has no source reference.
#| utils::getSrcFilename : (x:any, full.names:lgl1?, unique:lgl1?) -> CHR<>
#| utils::getSrcLocation : (x:any, which:chr1?, first:lgl1?) -> INT<> | null
#| utils::getSrcref : (x:any) -> dyn
# The parse data of a srcfile: a data frame of the tokens, `NULL` without
# one.
#| utils::getParseData : (x:any, includeText:any?) -> { any }<data.frame> with { names: CHR, any } | null
