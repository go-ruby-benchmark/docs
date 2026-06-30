# Performance

`go-ruby-benchmark/benchmark` is the pure-Go library that
[`rbgo`](https://github.com/go-embedded-ruby/ruby) binds for Ruby's `Benchmark`.
This page records the **methodology** of the comparative benchmark of that module
against the reference Ruby runtimes, part of the ecosystem-wide per-module parity
suite.

!!! note "Methodology only"
    No measured numbers are published here yet. This page documents *how* the
    benchmark is run so the result is reproducible and apples-to-apples; the
    measured table will be added once the run is recorded, the same way it is for
    the sibling modules — never fabricated.

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
