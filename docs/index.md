# go-ruby-benchmark documentation

**Ruby's Benchmark module in pure Go — MRI-compatible, no cgo.**

`go-ruby-benchmark/benchmark` is a faithful, pure-Go (zero cgo) reimplementation of
Ruby's standard-library `Benchmark` module — the deterministic, interpreter-independent
core of MRI 4.0.5 (`benchmark` 0.5.0) — reproducing MRI's formatted output
byte-for-byte. The module path is `github.com/go-ruby-benchmark/benchmark`.

It implements the `Tms` measurement value type, its memberwise arithmetic and
`%`-directive formatting, and the report layout (`CAPTION`, label justification, the
`bm` / `bmbm` / `benchmark` tables). It was **extracted from rbgo's internals into a
reusable standalone library**: the module is standalone and importable by any Go
program, and it is the backend bound into
[go-embedded-ruby](https://github.com/go-embedded-ruby/ruby) by `rbgo` as a native
module — just like [go-ruby-regexp](https://github.com/go-ruby-regexp) and
[go-ruby-erb](https://github.com/go-ruby-erb). The dependency runs the other way:
this library has **no dependency on the Ruby runtime**.

!!! success "Status: complete — MRI byte-exact"
    The `Tms` value type, memberwise and scalar arithmetic, the `Format` `%`-extensions (`%u %y %U %Y %t %r %n`), and the full report layout — `CAPTION`, label justification, and the `bm`, `bmbm`, and general `benchmark` tables with summary lines — all as pure functions over `Tms` with an injected `Clock` seam. Validated **byte-for-byte** against the system `ruby` at 100% coverage, `gofmt` + `go vet` clean, CI green across the six 64-bit Go targets and three OSes.

## What it is — and isn't

Formatting a `Tms`, doing its memberwise arithmetic, and laying out the report
tables is fully deterministic and needs **no interpreter**, so it lives here as
pure Go. The one impure ingredient — the **clock** — is injected: MRI's
`Benchmark.measure` reads `Process.times` (the four CPU times) and
`Process.clock_gettime(CLOCK_MONOTONIC)` (real time), and this library takes those
readings through a small `Clock` interface. The host (go-embedded-ruby) wires in
the real process clock; tests feed a fixed clock so every formatted line is
reproducible.

## Quick taste

```go
clock := realClock{start: time.Now()}

t := benchmark.MeasureWith(clock, "build", func() { _ = make([]byte, 1<<20) })
fmt.Print(t.ToS())
// e.g. "  0.000000   0.000000   0.000000 (  0.000123)"

out, _ := benchmark.Bm(clock, 7, nil, func(r *benchmark.Report) []benchmark.Tms {
	r.Run("warm:", func() { _ = make([]byte, 1<<20) })
	return nil
})
fmt.Print(out)
```

## Repositories

| Repo | What it is |
| --- | --- |
| [`benchmark`](https://github.com/go-ruby-benchmark/benchmark) | the library — Ruby's Benchmark module in pure Go |
| [`docs`](https://github.com/go-ruby-benchmark/docs) | this documentation site (MkDocs Material, versioned with mike) |
| [`go-ruby-benchmark.github.io`](https://github.com/go-ruby-benchmark/go-ruby-benchmark.github.io) | the organization landing page (Hugo) |
| [`brand`](https://github.com/go-ruby-benchmark/brand) | logo and brand assets |

## Principles

- **Pure Go, `CGO_ENABLED=0`** — trivial cross-compilation, a single static
  binary, no C toolchain.
- **MRI byte-exact.** The formatted `Tms`, the `%`-directive output, and the report
  tables match reference Ruby exactly, validated by a differential oracle against
  the `ruby` binary.
- **The clock is injected.** Measurement is the only impure part, supplied through
  a `Clock` seam: the host wires the real process clock, tests feed a fixed one.
- **Standalone & reusable.** Extracted from rbgo's internals; no dependency on the
  Ruby runtime — the dependency runs the other way.
- **100% test coverage** is the target, enforced as a CI gate, across 6 arches and
  3 OSes.

## Where to go next

- [Why pure Go](why.md) — why this slice of Ruby is deterministic enough to live
  as a standalone, interpreter-independent Go library.
- [Usage & API](api.md) — the public surface and worked examples.
- [Roadmap](roadmap.md) — what is done and what is downstream by design.

Source lives at [github.com/go-ruby-benchmark/benchmark](https://github.com/go-ruby-benchmark/benchmark).
