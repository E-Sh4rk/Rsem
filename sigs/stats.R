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

# The arithmetic of time series keeps their class (when both operands are
# time series, it is computed on the intersection of their windows). As the
# methods of `base`, they cover every value of the class, and have no type
# variables (cf. base.R).
#| stats::(+.ts) : (e1:dbl1<ts, ...>, e2:dbl1?) -> (DBL1|INT1)<ts, ...>
#| stats::(+.ts) : (e1:dbl<ts, ...>, e2:dbl?) -> (DBL|INT)<ts, ...>
#| stats::(-.ts) : (e1:dbl1<ts, ...>, e2:dbl1?) -> (DBL1|INT1)<ts, ...>
#| stats::(-.ts) : (e1:dbl<ts, ...>, e2:dbl?) -> (DBL|INT)<ts, ...>
#| stats::(*.ts) : (e1:dbl1<ts, ...>, e2:dbl1) -> (DBL1|INT1)<ts, ...>
#| stats::(*.ts) : (e1:dbl<ts, ...>, e2:dbl) -> (DBL|INT)<ts, ...>
#| stats::(/.ts) : (e1:dbl1<ts, ...>, e2:dbl1) -> DBL1<ts, ...>
#| stats::(/.ts) : (e1:dbl<ts, ...>, e2:dbl) -> DBL<ts, ...>

# Subsetting a time series loses its time window, and so its class.
#| stats::([].ts) : (x:v('a)<ts, ...>, ...: dbl|CHR) -> v('a)<>
#| stats::([].ts) : (x:{any}<ts, ...>, ...: dbl|CHR) -> any
