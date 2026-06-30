# Roadmap

`go-ruby-benchmark/benchmark` is grown **test-first**, each capability
differential-tested against MRI rather than built in isolation. Ruby's `Benchmark`
module — the deterministic, interpreter-independent slice extracted from rbgo's
internals — is **complete**.

| Stage | What | Status |
| --- | --- | --- |
| Tms value type | `utime`, `stime`, `cutime`, `cstime`, `real`, the derived `total`, and a `label`, with `ToA` / `ToS` and MRI-exact constructor semantics (a sum's label clears to `""`). | **Done** |
| Memberwise & scalar arithmetic | `Add` / `Sub` / `Mul` / `Div` against another `Tms`, and the scalar forms applied to all five fields (real included) — exactly as MRI's `Tms#+ - * /`. | **Done** |
| Format directives | The Benchmark `%`-extensions over printf (`%u %y %U %Y %t %r %n`), each preserving its flag/width/precision run, with `%%` collapse and surplus-arg drop matching `String#%`. | **Done** |
| Report layout | `CAPTION`, label justification, and the full `bm`, `bmbm` (rehearsal + take table), and general `benchmark` tables with summary lines — all pure functions over `Tms`. | **Done** |
| Injected clock | `MeasureWith`, `RealtimeWith`, `MsWith`, and `Tms.AddWith` take a `Clock` seam (`Process.times` + `clock_gettime(CLOCK_MONOTONIC)`); host supplies the real clock, tests a deterministic one. | **Done** |
| Differential oracle & coverage | The same fixed numbers and a patched, deterministic clock fed to the system `ruby`'s `Benchmark` and compared byte-for-byte; 100% coverage, gofmt + go vet clean, green across all six 64-bit Go arches and three OSes. | **Done** |

## Documented out-of-scope boundaries

These are **deliberate**, recorded so the module's surface is unambiguous:

- **The clock is the consumer's.** The library never reads the system clock
  itself; measurement (`Process.times` + `clock_gettime`) is injected through the
  `Clock` seam. The host supplies the real process clock — that is why `rbgo` binds
  this module rather than the reverse.
- **Reference is reference Ruby (MRI).** Byte-for-byte conformance targets MRI's
  formatted output; differences across MRI releases are matched to the reference
  used by the differential oracle.
- **Standalone & reusable.** The module has no dependency on the Ruby runtime; the
  dependency runs the other way.

See [Usage & API](api.md) for the surface and [Why pure Go](why.md) for the
deterministic/clock split.
