<!-- SPDX-License-Identifier: BSD-3-Clause -->
# `go-ruby-benchmark` library-level benchmark harness

Reproducible, cross-runtime benchmark of the **pure-Go `go-ruby-benchmark/benchmark`
library** against the reference Ruby runtimes (MRI, MRI + YJIT, JRuby,
TruffleRuby). It measures the **library primitives** through their Go API,
isolated from the rbgo interpreter, so the numbers answer: *is the pure-Go
implementation as fast as the reference runtime's own `Benchmark`?*

## The "benchmarking the benchmarker" gotcha

`Benchmark`'s whole job is to **measure elapsed time**, so timing its wall-clock
measurement would be meta and non-deterministic — there is nothing byte-stable to
compare. This harness instead benchmarks the module's **deterministic, pure
functions over FIXED `Tms` values**:

- `tms-arith` — memberwise `Tms` arithmetic (`+ - * /`).
- `tms-format-default` — `Tms#to_s` (the default `FORMAT`).
- `tms-format-custom` — `Tms#format` with a custom directive string.
- `report-table` — the `Benchmark#benchmark` bm-table caption + row formatting,
  given fixed `Tms` rows.

Because the `Tms` values are fixed (never a real measured time), every runtime
produces **byte-identical** output. `run.sh` verifies Go output == MRI output
byte-for-byte (the drivers' `emit` mode) **before** any timing — divergent
implementations are never timed.

## Layout

- `go/`                — self-contained Go driver; `go.mod` pins the published
  library by pseudo-version (no `replace`).
- `ruby/benchmark.rb`  — the equivalent workload; `ruby/_harness.rb` is the shared timer.
- `run.sh`             — verifies parity, then runs every available runtime and
  prints one Markdown table per sub-benchmark (ns/op + ratio vs MRI).

## Run

```sh
bash benchmarks/run.sh
```

Environment knobs: `OUTER` (timed passes, default 25), `WARM` (untimed warm-up
passes, default 3), and `RUBY`/`JRUBY`/`TRUFFLERUBY` to select runtime binaries.

## Method

Each process runs `WARM` untimed passes (to let the JVM/GraalVM JITs warm up),
then `OUTER` timed passes of a fixed inner loop, timed with a monotonic clock;
the **best** pass is reported as **ns/op**. Interpreter start-up is outside the
timed region. The Go driver and the Ruby script build **identical inputs** (the
same fixed `Tms` operands) and their `emit` outputs are checked identical to MRI
before timing. Results are published, dated, in `../docs/performance.md`.
