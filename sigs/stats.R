# Signatures of R's `stats` package, and of the S3 methods it defines for the
# generics of `base` (cf. "Class-overloads" in base.R). They are in a file of
# their own, as the methods of a package only exist when it is loaded.

# ========== Methods ==========

# The S3 generics of `stats` (cf. "Methods" in base.R), with the return type R's
# conventions give their methods, when there is one.
#| method stats::add1
#| method stats::aggregate
#| method stats::AIC
#| method stats::alias
#| method stats::anova
#| method stats::ansari.test
#| method stats::ar.burg
#| method stats::ar.yw
#| method stats::as.dendrogram : <dendrogram, ...>
#| method stats::as.dist : <dist, ...>
#| method stats::as.hclust : <hclust, ...>
#| method stats::as.stepfun
#| method stats::as.ts : <ts, ...>
#| method stats::bartlett.test
#| method stats::BIC
#| method stats::biplot
#| method stats::case.names
#| method stats::coef
#| method stats::coefficients
#| method stats::confint
#| method stats::cooks.distance
#| method stats::cophenetic
#| method stats::cor.test
#| method stats::cycle
#| method stats::deltat
#| method stats::density
#| method stats::deriv
#| method stats::deriv3
#| method stats::deviance
#| method stats::df.residual
#| method stats::dfbeta
#| method stats::dfbetas
#| method stats::dffits
#| method stats::diffinv
#| method stats::drop1
#| method stats::dummy.coef
#| method stats::effects
#| method stats::end
#| method stats::estVar
#| method stats::extractAIC
#| method stats::family
#| method stats::fitted
#| method stats::fitted.values
#| method stats::fligner.test
#| method stats::formula
#| method stats::free1way
#| method stats::frequency
#| method stats::friedman.test
#| method stats::ftable
#| method stats::getCall
#| method stats::getInitial
#| method stats::hatvalues
#| method stats::influence
#| method stats::kernapply
#| method stats::knots
#| method stats::kruskal.test
#| method stats::ks.test
#| method stats::lag
#| method stats::logLik
#| method stats::makepredictcall
#| method stats::mauchly.test
#| method stats::median
#| method stats::model.frame
#| method stats::model.matrix
#| method stats::model.tables
#| method stats::monthplot
#| method stats::mood.test
#| method stats::na.action
#| method stats::na.contiguous
#| method stats::na.exclude
#| method stats::na.fail
#| method stats::na.omit
#| method stats::napredict
#| method stats::naprint
#| method stats::naresid
#| method stats::NLSstAsymptotic
#| method stats::NLSstClosestX
#| method stats::NLSstLfAsymptote
#| method stats::NLSstRtAsymptote
#| method stats::nobs
#| method stats::pacf
#| method stats::ppr
#| method stats::prcomp
#| method stats::predict
#| method stats::preplot
#| method stats::princomp
#| method stats::profile
#| method stats::proj
#| method stats::qqnorm
#| method stats::quade.test
#| method stats::quantile
#| method stats::relevel
#| method stats::reorder
#| method stats::resid
#| method stats::residuals
#| method stats::rstandard
#| method stats::rstudent
#| method stats::screeplot
#| method stats::se.contrast
#| method stats::selfStart
#| method stats::sigma
#| method stats::simulate
#| method stats::sortedXyData
#| method stats::SSD
#| method stats::start
#| method stats::t.test
#| method stats::terms
#| method stats::time
#| method stats::tsdiag
#| method stats::tsSmooth
#| method stats::TukeyHSD
#| method stats::update
#| method stats::var.test
#| method stats::variable.names
#| method stats::vcov
#| method stats::weighted.mean
#| method stats::weights
#| method stats::wilcox.test
#| method stats::window
#| method stats::window<-

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
# Random numbers: `n` of them (or as many as `n` has elements, when it is not a
# single number). The counts may be doubles, when too large for integers.
#| stats::runif : (n:dbl, min:dbl?, max:dbl?) -> DBL<>
#| stats::rnorm : (n:dbl, mean:dbl?, sd:dbl?) -> DBL<>
#| stats::rlnorm : (n:dbl, meanlog:dbl?, sdlog:dbl?) -> DBL<>
#| stats::rexp : (n:dbl, rate:dbl?) -> DBL<>
#| stats::rgamma : (n:dbl, shape:dbl, rate:dbl?, scale:dbl?) -> DBL<>
#| stats::rbeta : (n:dbl, shape1:dbl, shape2:dbl, ncp:dbl?) -> DBL<>
#| stats::rt : (n:dbl, df:dbl, ncp:dbl?) -> DBL<>
#| stats::rchisq : (n:dbl, df:dbl, ncp:dbl?) -> DBL<>
#| stats::rweibull : (n:dbl, shape:dbl, scale:dbl?) -> DBL<>
#| stats::rpois : (n:dbl, lambda:dbl) -> INT<> | DBL<>
#| stats::rbinom : (n:dbl, size:dbl, prob:dbl) -> INT<> | DBL<>
# The density and the distribution function of the normal distribution.
#| stats::dnorm : (x:dbl1, mean:dbl1?, sd:dbl1?, log:lgl1?) -> DBL1<>
#|             && (x:dbl, mean:dbl?, sd:dbl?, log:lgl1?) -> DBL<>
#| stats::pnorm : (q:dbl1, mean:dbl1?, sd:dbl1?, lower.tail:lgl1?, log.p:lgl1?) -> DBL1<>
#|             && (q:dbl, mean:dbl?, sd:dbl?, lower.tail:lgl1?, log.p:lgl1?) -> DBL<>

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
#| stats::var : (x:dbl, y:dbl|null?, na.rm:lgl1?, use:CHR1?) -> DBL<> with { dim: INT?, dimnames: list?, any }
#| stats::cov : (x:dbl, y:dbl|null?, use:CHR1?, method:CHR1?) -> DBL<> with { dim: INT?, dimnames: list?, any }

# The residuals and the weights of a fitted model (the weights are `NULL` for
# an unweighted one); both are generic.
#| stats::residuals : (object:any, ...: any) -> DBL<>
#| stats::weights : (object:any, ...: any) -> DBL<> | null

# The summary of a linear model: a list of its statistics (`fstatistic`
# only when the model has more than an intercept).
#| stats::summary.lm : (object:any, correlation:lgl1?, symbolic.cor:lgl1?, ...: any) -> { call: lang, terms: any, residuals: DBL, coefficients: DBL, aliased: LGL, sigma: DBL1, df: INT, r.squared: DBL1, adj.r.squared: DBL1, fstatistic: DBL?, cov.unscaled: DBL, any }<summary.lm>
