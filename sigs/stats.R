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
# The time window of a time series, `NULL` for other values.
#| stats::tsp : (x:any with { tsp: 'a, any }) -> 'a
#|           && (x:any) -> DBL<> | null
#| stats::frequency : (x:any, ...: any) -> DBL1<>
#| stats::start : (x:any, ...: any) -> DBL<>
#| stats::end : (x:any, ...: any) -> DBL<>
# The times of the observations, a time series itself. `time` is generic: the
# methods of other classes (e.g. zoo's) give other types.
#| stats::time : (x:<ts, ...>, ...: any) -> DBL<ts> with { tsp: DBL, any }
#|             && (x:any, ...: any) -> any
# `as.ts` is generic. The default method makes a vector a time series, and
# returns a time series unchanged; the methods of other classes (e.g. zoo's)
# give time series as well.
#| stats::as.ts : (x:(v('a)&dbl)<>, ...: any) -> v('a)<ts> with { tsp: DBL, any }
#|             && (x:any, ...: any) -> <ts, ...> with { tsp: DBL, any }

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
#| stats::hclust : (d:any, method:chr1?, members:any?) -> { merge: INT, height: DBL, order: INT, labels: CHR | null, method: CHR | null, call: any, dist.method: CHR | null, any }<hclust>
#| stats::as.hclust : (x:any, ...: any) -> { merge: INT, height: DBL, order: INT, labels: CHR | null, method: CHR | null, call: any, dist.method: CHR | null, any }<hclust>
# The groups of a hierarchical clustering cut into `k` groups (or at the
# height `h`): a group per observation (a matrix of them for several `k`).
#| stats::cutree : (tree:any, k:dbl|null?, h:dbl|null?) -> INT<> with { dim: INT?, any }
#| stats::as.dendrogram : (object:any, ...: any) -> { any }<dendrogram>
# A distance matrix: its lower triangle as a vector, of class `dist`, with
# the number of observations as `Size`.
#| stats::as.dist : (m:any, diag:lgl1?, upper:lgl1?) -> DBL<dist> with { Size: INT1, any }
#| stats::cophenetic : (x:any) -> DBL<dist> with { Size: INT1, any }

# The generics of models. `coef` gives the coefficients (a matrix for several
# responses), `vcov` their covariance matrix.
# A model's predictions: of which the type, depending on the class of the
# model, says nothing (as `summary`'s).
#| stats::predict : (object:any, ...: any) -> dyn
# The data frame of the variables of a model, with its `terms`.
#| stats::model.frame : (formula:any, ...: any) -> { any }<data.frame> with { names: CHR, terms: any, any }
# The diagonal of the hat matrix of a model.
#| stats::hatvalues : (model:any, ...: any) -> DBL<>
# A link function of a GLM family (`"logit"`, ...): its functions and name.
#| stats::make.link : (link:chr1) -> { linkfun: (eta:dbl) -> DBL<>, linkinv: (eta:dbl) -> DBL<>, mu.eta: (eta:dbl) -> DBL<>, valideta: (eta:dbl) -> LGL1<>, name: CHR1, any }<"link-glm">
#| stats::coef : (object:any, ...: any) -> DBL<>
#| stats::vcov : (object:any, ...: any) -> DBL<> with { dim: INT, dimnames: list?, any }
# `x` with the omitted cases (`na.action` of class `exclude`) put back as
# `NA`; without them (`NULL`), `x` itself.
#| stats::naresid : (omit:any, x:'a, ...: any) -> 'a

# ========== Distributions ==========

#| stats::qnorm : (p:dbl1, mean:dbl1?, sd:dbl1?, lower.tail:lgl1?, log.p:lgl1?) -> DBL1<>
#|             && (p:dbl, mean:dbl?, sd:dbl?, lower.tail:lgl1?, log.p:lgl1?) -> DBL<>
#| stats::qt : (p:dbl1, df:dbl1, ncp:dbl1?, lower.tail:lgl1?, log.p:lgl1?) -> DBL1<>
#|          && (p:dbl, df:dbl, ncp:dbl?, lower.tail:lgl1?, log.p:lgl1?) -> DBL<>
#| stats::qchisq : (p:dbl1, df:dbl1, ncp:dbl1?, lower.tail:lgl1?, log.p:lgl1?) -> DBL1<>
#|              && (p:dbl, df:dbl, ncp:dbl?, lower.tail:lgl1?, log.p:lgl1?) -> DBL<>
#| stats::runif : (n:dbl, min:dbl?, max:dbl?) -> DBL<>

# ========== Summaries ==========

# The median, of the mode of `x` (an integer when the middle values are
# equal); `median` is generic: of another class, a result of which the type
# says nothing.
#| stats::median : (x:dbl, na.rm:lgl1?, ...: any) -> (DBL1|INT1)<>
#|              && (x:any, na.rm:lgl1?, ...: any) -> dyn
#| stats::weighted.mean : (x:dbl, w:dbl?, ...: any, na.rm:lgl1?) -> DBL1<>
#| stats::sd : (x:dbl, na.rm:lgl1?) -> DBL1<>
# The variance of a vector, or the covariance matrix of the columns of a
# matrix (or between `x` and `y`).
#| stats::var : (x:dbl, y:dbl|null?, na.rm:lgl1?, use:chr1?) -> DBL<> with { dim: INT?, dimnames: list?, any }
#| stats::cov : (x:dbl, y:dbl|null?, use:chr1?, method:chr1?) -> DBL<> with { dim: INT?, dimnames: list?, any }

# The residuals and the weights of a fitted model (the weights are `NULL` for
# an unweighted one); both are generic.
#| stats::residuals : (object:any, ...: any) -> DBL<>
#| stats::weights : (object:any, ...: any) -> DBL<> | null

# The summary of a linear model: a list of its statistics (`fstatistic`
# only when the model has more than an intercept).
#| stats::summary.lm : (object:any, correlation:lgl1?, symbolic.cor:lgl1?, ...: any) -> { call: lang, terms: any, residuals: DBL, coefficients: DBL, aliased: LGL, sigma: DBL1, df: INT, r.squared: DBL1, adj.r.squared: DBL1, fstatistic: DBL?, cov.unscaled: DBL, any }<summary.lm>
