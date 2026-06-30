# Usage & API

The public API lives at the module root
(`github.com/go-ruby-benchmark/benchmark`). It is **Ruby-shaped but Go-idiomatic**:
the methods mirror `Benchmark` / `Benchmark::Tms`, while the surface follows Go
conventions — value types, an explicit injected `Clock`, no global state.

!!! success "Status: implemented"
    The library is built and importable as
    `github.com/go-ruby-benchmark/benchmark`, bound into `rbgo` as a native module;
    see [Roadmap](roadmap.md).

## Install

```sh
go get github.com/go-ruby-benchmark/benchmark
```

## Worked example

```go
package main

import (
	"fmt"
	"time"

	benchmark "github.com/go-ruby-benchmark/benchmark"
)

// realClock implements benchmark.Clock with the process's real wall clock.
type realClock struct{ start time.Time }

func (c realClock) Times() (u, s, cu, cs float64) { return 0, 0, 0, 0 }
func (c realClock) Monotonic() float64            { return time.Since(c.start).Seconds() }

func main() {
	clock := realClock{start: time.Now()}

	// Benchmark.measure { ... } → a Tms.
	t := benchmark.MeasureWith(clock, "build", func() { _ = make([]byte, 1<<20) })
	fmt.Print(t.ToS())

	// Benchmark.bm(7) { |x| x.report("...") { ... } } → the table.
	out, _ := benchmark.Bm(clock, 7, nil, func(r *benchmark.Report) []benchmark.Tms {
		r.Run("warm:", func() { _ = make([]byte, 1<<20) })
		r.Run("cold:", func() { _ = make([]byte, 1<<20) })
		return nil
	})
	fmt.Print(out)
}
```

## API

```go
// Constants matching Benchmark::CAPTION / FORMAT / BENCHMARK_VERSION.
const CAPTION = "      user     system      total        real\n"
const FORMAT  = "%10.6u %10.6y %10.6t %10.6r\n"
const BenchmarkVersion = "2002-04-25"

// Tms — the measurement value type (Benchmark::Tms).
func NewTms(utime, stime, cutime, cstime, real float64, label string) Tms
func (t Tms) Utime() float64
func (t Tms) Stime() float64
func (t Tms) Cutime() float64
func (t Tms) Cstime() float64
func (t Tms) Real() float64
func (t Tms) Total() float64   // utime+stime+cutime+cstime
func (t Tms) Label() string
func (t Tms) ToA() []any       // [label, utime, stime, cutime, cstime, real]
func (t Tms) ToS() string
func (t Tms) Format(format string, args ...any) string

func (t Tms) Add(o Tms) Tms        // Tms#+
func (t Tms) Sub(o Tms) Tms        // Tms#-
func (t Tms) Mul(o Tms) Tms        // Tms#*
func (t Tms) Div(o Tms) Tms        // Tms#/
func (t Tms) AddScalar(x float64) Tms
func (t Tms) SubScalar(x float64) Tms
func (t Tms) MulScalar(x float64) Tms
func (t Tms) DivScalar(x float64) Tms

// The injected clock seam (Process.times + clock_gettime(CLOCK_MONOTONIC)).
type Clock interface {
	Times() (utime, stime, cutime, cstime float64)
	Monotonic() float64
}
func MeasureWith(clock Clock, label string, fn func()) Tms   // Benchmark.measure
func RealtimeWith(clock Clock, fn func()) float64            // Benchmark.realtime
func MsWith(clock Clock, fn func()) float64                  // Benchmark.ms
func (t Tms) AddWith(clock Clock, fn func()) Tms             // Tms#add

// Report layout (Benchmark::Report / #benchmark / #bm / #bmbm).
type Report struct{ /* … */ }
func NewReport(clock Clock, width int, format string) *Report
func (r *Report) Run(label string, fn func()) Tms
func (r *Report) Line(t Tms) string
func (r *Report) Caption() string
func (r *Report) ExtraLine(labelWidth int, label string, t Tms) string

type Job struct{ /* … */ }
func NewJob(width int) *Job
func (j *Job) Item(label string, fn func()) *Job

func Benchmark(clock Clock, caption string, labelWidth int, format string,
	extraLabels []string, build func(*Report) []Tms) (string, []Tms)
func Bm(clock Clock, labelWidth int, extraLabels []string,
	build func(*Report) []Tms) (string, []Tms)
func Bmbm(clock Clock, job *Job) (string, []Tms)
```

## The Format directives

`Format` adds the Benchmark `%`-extensions on top of standard printf directives:
`%u` user, `%y` system, `%U` / `%Y` children's user/system, `%t` total, `%r` real
(wrapped in parentheses), `%n` label — each preserving its flag/width/precision run
(e.g. `%10.6u`). `%%` collapses and surplus args are dropped, matching Ruby's
`String#%`. The default `FORMAT` is `"%10.6u %10.6y %10.6t %10.6r\n"`.

## MRI conformance

Correctness is defined by reference Ruby. A **differential oracle** feeds the same
fixed numbers and a patched, deterministic clock to the system `ruby`'s `Benchmark`
and compares the formatted output **byte-for-byte** — not approximated from memory.
The oracle scripts `$stdout.binmode` so Windows text-mode never pollutes the bytes,
and skip themselves where `ruby` is absent or on Windows, so the cross-arch and
Windows lanes still validate the library.

## Relationship to Ruby

`go-ruby-benchmark/benchmark` is **standalone and reusable**, and is the backend
bound into [go-embedded-ruby](https://github.com/go-embedded-ruby/ruby) by `rbgo`
as a native module — the same way [go-ruby-regexp](https://github.com/go-ruby-regexp)
and [go-ruby-erb](https://github.com/go-ruby-erb) are bound. The host supplies the
real process clock; this library has no dependency on the Ruby runtime.
