# Why pure Go

`go-ruby-benchmark/benchmark` reimplements Ruby's standard-library `Benchmark`
module in **pure Go, with cgo disabled**. The slice of Ruby it covers — formatting
a `Tms`, its memberwise arithmetic, and the report-table layout — is
**deterministic and interpreter-independent**: given its inputs (and the clock
readings), the result is a pure function of those inputs. That is exactly the part
that can — and should — live as a standalone Go library, separate from the
interpreter.

## The deterministic core vs. the clock

Everything `Benchmark` does on top of a measurement is deterministic: the `Tms`
arithmetic, the `%u %y %t %r` format directives, and the `bm` / `bmbm` / `benchmark`
table layout are pure functions of their inputs and live here. The **one** impure
ingredient is the measurement itself — reading `Process.times` and
`Process.clock_gettime(CLOCK_MONOTONIC)`. That is isolated behind a small `Clock`
interface and injected: the host wires the real process clock, and tests feed a
fixed clock, so every formatted line — down to the byte — is reproducible.

## Extracted from rbgo, reusable by anyone

This library began life inside
[go-embedded-ruby](https://github.com/go-embedded-ruby/ruby)'s `rbgo`. It has been
**extracted into a reusable standalone library** so that:

- any Go program can import `github.com/go-ruby-benchmark/benchmark` directly, with
  no Ruby runtime;
- the dependency runs the *other* way — `rbgo` binds this module as a native module
  (the same pattern as [go-ruby-regexp](https://github.com/go-ruby-regexp) and
  [go-ruby-erb](https://github.com/go-ruby-erb)), rather than this module depending
  on the interpreter;
- the behavior is pinned by a **differential oracle** against the system `ruby`,
  fed the same fixed numbers and a deterministic clock, independent of any one
  consumer.

## Why pure Go matters here

Because the library is CGO-free and dependency-free, it:

- cross-compiles to every Go target with no C toolchain, and links into a single
  static binary;
- has **no dependency on the Ruby runtime** — the dependency runs the other way;
- can be differentially tested against the `ruby` binary wherever one is on `PATH`,
  while the cross-arch and Windows lanes (where `ruby` is absent) still validate the
  library itself, since the deterministic clock keeps every formatted line
  reproducible and ruby-free.

See [Usage & API](api.md) for the surface and [Roadmap](roadmap.md) for what is in
scope.
