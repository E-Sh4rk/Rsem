# Signatures of R's `stats` package, and of the S3 methods it defines for the
# generics of `base` (cf. "Class-overloads" in base.R). They are in a file of
# their own, as the methods of a package only exist when it is loaded.

# ========== Class-overloads ==========

# The time series: their arithmetic (the `Ops` group) and their subsets.
#| new stats::(+) @ ts
#| new stats::(-) @ ts
#| new stats::(*) @ ts
#| new stats::(/) @ ts
#| new stats::([]) @ ts

# ========== Time series ==========

# A time series is a vector with the class `ts` and its time window, the
# `tsp` attribute (start, end and frequency).
#| stats::ts : (data:v('a)&dbl, start:dbl?, end:dbl?, frequency:dbl1?, ...: any) -> v('a)<ts> with { tsp: DBL, any }
#| stats::frequency : (x:any, ...: any) -> DBL1<>
#| stats::start : (x:any, ...: any) -> DBL<>
#| stats::end : (x:any, ...: any) -> DBL<>
# The times of the observations, a time series itself. `time` is generic: the
# methods of other classes (e.g. zoo's) give other types.
#| stats::time : (x:<ts, ...>, ...: any) -> DBL<ts> with { tsp: DBL, any }
#|             && (x:any, ...: any) -> any

# The arithmetic of time series keeps their class (when both operands are
# time series, it is computed on the intersection of their windows). As the
# methods of `base`, they cover every value of the class, and have no type
# variables (cf. base.R).
#| stats::(+.ts) : (e1:dbl1<ts, ...>, e2:dbl1?) -> (DBL1|INT1)<ts, ...>
#|              && (e1:dbl<ts, ...>, e2:dbl?) -> (DBL|INT)<ts, ...>
#| stats::(-.ts) : (e1:dbl1<ts, ...>, e2:dbl1?) -> (DBL1|INT1)<ts, ...>
#|              && (e1:dbl<ts, ...>, e2:dbl?) -> (DBL|INT)<ts, ...>
#| stats::(*.ts) : (e1:dbl1<ts, ...>, e2:dbl1) -> (DBL1|INT1)<ts, ...>
#|              && (e1:dbl<ts, ...>, e2:dbl) -> (DBL|INT)<ts, ...>
#| stats::(/.ts) : (e1:dbl1<ts, ...>, e2:dbl1) -> DBL1<ts, ...>
#|              && (e1:dbl<ts, ...>, e2:dbl) -> DBL<ts, ...>

# Subsetting a time series loses its time window, and so its class.
#| stats::([].ts) : (x:v('a)<ts, ...>, ...: dbl|CHR) -> v('a)<>
#| stats::([].ts) : (x:{any}<ts, ...>, ...: dbl|CHR) -> any

# ========== Models ==========

# The design matrix of a model, with the column of each term in `assign`.
#| stats::model.matrix : (object:any, ...: any) -> DBL<> with { dim: INT, dimnames: list?, assign: INT, any }
# A hierarchical clustering, from the methods of the classes that have one.
#| stats::as.hclust : (x:any, ...: any) -> { merge: INT, height: DBL, order: INT, labels: CHR | null, method: CHR | null, call: any, dist.method: CHR | null, any }<hclust>

# The generics of models. `coef` gives the coefficients (a matrix for several
# responses), `vcov` their covariance matrix.
#| stats::coef : (object:any, ...: any) -> DBL<>
#| stats::vcov : (object:any, ...: any) -> DBL<> with { dim: INT, dimnames: list?, any }
# `x` with the omitted cases (`na.action` of class `exclude`) put back as
# `NA`; without them (`NULL`), `x` itself.
#| stats::naresid : (omit:any, x:'a, ...: any) -> 'a

# ========== Distributions ==========

#| stats::qnorm : (p:dbl1, mean:dbl1?, sd:dbl1?, lower.tail:lgl1?, log.p:lgl1?) -> DBL1<>
#|             && (p:dbl, mean:dbl?, sd:dbl?, lower.tail:lgl1?, log.p:lgl1?) -> DBL<>
