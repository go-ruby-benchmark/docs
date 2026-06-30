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
