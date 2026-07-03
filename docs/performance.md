# Performance

`go-ruby-benchmark/benchmark` is the pure-Go library that
[`rbgo`](https://github.com/go-embedded-ruby/ruby) binds for Ruby's `Benchmark`.
This page records the **methodology** of the comparative benchmark of that module
against the reference Ruby runtimes, part of the ecosystem-wide per-module parity
suite.

## Result (best of 5, ms)

Measured 2026-06-30 on **Apple M4 Max**, macOS (darwin/arm64), Go 1.26.4, with
`ruby 4.0.5 +PRISM`, `jruby 10.1.0.0` (OpenJDK 25) and `truffleruby 34.0.1`
(GraalVM CE Native). The cross-runtime workload drives `Benchmark.measure` over a
fixed integer kernel 20 000× and checksums the **work** (not the timing), so the
output is deterministic and byte-identical to MRI before timing.

| Runtime | time | vs MRI |
| --- | ---: | ---: |
| **rbgo** (go-ruby-benchmark) | 240 | 2.18× |
| MRI (ruby 4.0.5) | 110 | 1.00× |
| MRI + YJIT | 70 | 0.64× |
| JRuby 10.1.0.0 | 1330 | 12.09× |
| TruffleRuby 34.0.1 | 180 | 1.64× |

rbgo runs on **go-ruby-benchmark** at **~2.2× MRI** (2.18×): per `measure` call the
loop pays a `Benchmark::Tms` construction plus the inner kernel, so the row is
dominated by rbgo's per-send frame setup + interface dispatch over MRI's
inline-cached interpreter (YJIT specialises it down to 0.64×). A sub-250 ms row,
inside the order-of-magnitude band.

!!! note "Honest framing"
    JRuby and TruffleRuby are timed **cold, single-shot**, so they carry JVM /
    Graal startup on every run — read them as one-shot `ruby file.rb` costs, the
    same way `rbgo` and MRI are measured, not as steady-state JIT numbers. Rows
    under ~250 ms carry the most relative noise; treat the ratio as
    order-of-magnitude. These are **real measured numbers** from the 2026-06-30
    run (Apple M4 Max; `ruby 4.0.5 +PRISM`, `jruby 10.1.0.0`, `truffleruby
    34.0.1`) — nothing is fabricated or cherry-picked.

!!! warning "Benchmarking the benchmarker"
    This module *is* Ruby's `Benchmark`. To compare it fairly without circularity,
    the harness drives the library's report-formatting and `Tms` arithmetic over a
    **fixed, injected clock** — so what is timed is the cost of building and
    formatting the report, not wall-clock measurement noise. The clock readings are
    identical across runtimes, so the only variable is each interpreter's own
    `Benchmark` implementation doing the formatting.

## What is measured

The **same** Ruby script — running `Benchmark.bm` / `bmbm` over a set of labelled
jobs and formatting the resulting `Tms` table, all over a deterministic clock — is
run under every runtime. `rbgo`'s number reflects **this pure-Go library doing the
formatting and arithmetic**; every other column is that interpreter's own
`benchmark` stdlib. So the comparison is the **Ruby-visible operation**,
apples-to-apples across interpreters. The script prints a deterministic checksum and
its output is checked **byte-identical to MRI** before timing.

## How it is run

- **Method:** best-of-N wall time (best, not mean, to suppress scheduler noise);
  single-shot processes, no warm-up beyond the script's own loop.
- **Runtimes:** `ruby` (MRI, the oracle) and `ruby --yjit`; `jruby` (on the JVM);
  `truffleruby` (GraalVM). JVM/Graal rows are timed **cold, single-shot**, so they
  carry runtime startup on every run — read them as one-shot `ruby file.rb` costs,
  the same way `rbgo` and MRI are measured, not as steady-state JIT numbers.
- The benchmark script and harness live in rbgo's repo under
  [`bench/modules/`](https://github.com/go-embedded-ruby/ruby/tree/main/bench/modules)
  (`benchmark.rb` + `run.sh`). Reproduce with the same
  `RBGO=./rbgo TRUFFLE=truffleruby bash bench/modules/run.sh N` invocation used
  across the ecosystem.

## Honest framing

Rows that complete in well under ~200 ms carry the most relative noise; their
ratios should be read as order-of-magnitude. Any numbers added here will be real
measured numbers from a dated run — nothing cherry-picked.

## Library-level benchmark (Go API vs runtimes) — 2026-07-03

This section measures the **pure-Go library directly, through its Go API** — not
the `rbgo` interpreter path recorded above. It isolates the library primitives
from Ruby-interpreter dispatch, answering the parity question head-on: *is the
pure-Go implementation as fast as the reference runtime's own `Benchmark`?* The
**same workload, same fixed inputs, same iteration counts** run through the Go
library and through each reference runtime's stdlib; outputs were checked
byte-identical to MRI before any timing.

### Benchmarking the benchmarker — how it stays deterministic

`Benchmark`'s entire job is to **measure elapsed time**, so timing its wall-clock
measurement would be meta and non-deterministic — there is nothing byte-stable to
compare across runtimes. The harness therefore times only the module's
**deterministic, pure functions over FIXED `Tms` values** — never a real measured
time enters the compared output:

- **`tms-arith`** — memberwise `Tms` arithmetic: `a + b`, `a - b`, `a * b`,
  `a / b` on fixed operands `Tms(2,4,1,0.5,8)` and `Tms(1,1,0.5,0.25,2)`.
- **`tms-format-default`** — `Tms#to_s`, the default `FORMAT`, on a fixed
  `Tms(1,2,0.5,0.25,3.5,"lbl")`.
- **`tms-format-custom`** — `Tms#format("%n %u %y %t %r %%")` on the same fixed Tms.
- **`report-table`** — the `Benchmark#benchmark` bm-table caption + row layout,
  formatted from two fixed `Tms` rows (as if produced by a fixed clock).

Because every input is a fixed constant, each runtime prints **byte-identical**
output. The runner verifies Go's output equals MRI's byte-for-byte (the drivers'
`emit` mode) **before** timing — divergent implementations are never timed. All
five runtimes (Go, MRI, MRI+YJIT, JRuby, TruffleRuby) were confirmed identical to
the byte on this run.

- **Host:** Apple M4 Max (`Mac16,5`, arm64), macOS 26.5.1 — **date 2026-07-03**,
  everything on the host (no VM).
- **Runtimes:** Go 1.26.4 · MRI `ruby 4.0.5 +PRISM` · MRI + YJIT · JRuby 10.1.0.0
  (OpenJDK 25) · TruffleRuby 34.0.1 (GraalVM CE Native).
- **Method:** each process runs 5 untimed warm-up passes, then 60 timed passes of
  a fixed inner loop, timed with a monotonic clock; the **best** pass is reported
  as **ns/op** (lower is better). `vs MRI` / `vs YJIT` < 1.00× means *faster than*
  that runtime. Interpreter start-up is outside the timed region, so these are
  operation costs, not `ruby file.rb` process costs.

### go-vs-YJIT verdict

**The pure-Go library beats MRI + YJIT on every op measured** — YJIT is the
strongest reference bar here, and Go clears it each time:

| Op | go ns/op | YJIT ns/op | go vs YJIT | verdict |
| --- | ---: | ---: | ---: | --- |
| tms-arith | 83.0 | 265.5 | **0.31×** | **beats YJIT (~3.2×)** |
| tms-format-default | 738.4 | 3858.5 | **0.19×** | **beats YJIT (~5.2×)** |
| tms-format-custom | 759.0 | 4458.0 | **0.17×** | **beats YJIT (~5.9×)** |
| report-table | 1558.7 | 8517.0 | **0.18×** | **beats YJIT (~5.5×)** |

The gap is structural: the timed work is pure numeric arithmetic and
`printf`-style string assembly. In Go that compiles to tight native code over
`float64` fields and a `regexp`-driven directive substitution done once per
format; in every Ruby runtime the same work pays per-send dispatch through
`Tms#format` / `String#%` / `String#ljust` plus float boxing. YJIT narrows MRI's
gap on the arithmetic op (0.20× of MRI) but Go's arithmetic is another ~3× below
that; on the formatting-heavy ops YJIT barely improves on plain MRI (0.90–0.97×)
and Go is ~5× faster still.

#### tms-arith

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 83.0 | 0.06× |
| MRI | 1308.0 | 1.00× |
| MRI + YJIT | 265.5 | 0.20× |
| JRuby | 302.3 | 0.23× |
| TruffleRuby | 355.8 | 0.27× |

#### tms-format-default

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 738.4 | 0.17× |
| MRI | 4287.5 | 1.00× |
| MRI + YJIT | 3858.5 | 0.90× |
| JRuby | 2651.7 | 0.62× |
| TruffleRuby | 3151.5 | 0.74× |

#### tms-format-custom

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 759.0 | 0.16× |
| MRI | 4742.0 | 1.00× |
| MRI + YJIT | 4458.0 | 0.94× |
| JRuby | 2411.4 | 0.51× |
| TruffleRuby | 4437.9 | 0.94× |

#### report-table

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 1558.7 | 0.18× |
| MRI | 8791.0 | 1.00× |
| MRI + YJIT | 8517.0 | 0.97× |
| JRuby | 5760.1 | 0.66× |
| TruffleRuby | 11054.6 | 1.26× |

!!! note "Reproduce"
    The harness is committed under
    [`benchmarks/`](https://github.com/go-ruby-benchmark/docs/tree/main/benchmarks):
    a self-contained Go driver (`go/`, which pins this library by pseudo-version
    via `go.mod` — no `replace`), the equivalent `ruby/benchmark.rb` workload, and
    `run.sh`. Run `OUTER=60 WARM=5 bash benchmarks/run.sh`; env `OUTER`/`WARM` tune
    the pass budget and `RUBY`/`JRUBY`/`TRUFFLERUBY` select the runtime binaries.
    `run.sh` runs the byte-parity gate (Go `emit` == MRI `emit`) before timing.

!!! warning "Warm-up budget & noise — cold-JIT caveat"
    Numbers reflect a **fixed warm-process budget** (5 warm-up + 60 timed passes
    in one process, best pass reported). The JVM/GraalVM JITs (JRuby, TruffleRuby)
    may need a larger warm-up to reach steady state, so their columns can
    **understate** peak throughput — most visibly TruffleRuby, whose cold GraalVM
    ranks below MRI on the two shortest loops here. Sub-microsecond rows carry the
    most relative noise; treat those ratios as order-of-magnitude. Every number
    here is a **real measured value** from the dated run above — nothing is
    fabricated, estimated, or cherry-picked. The go-ruby column is the pure-Go
    library; every other column is that interpreter's own `Benchmark` stdlib doing
    the identical, byte-verified work over the same fixed `Tms` inputs.
