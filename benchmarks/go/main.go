// Copyright (c) the go-ruby-* authors
// SPDX-License-Identifier: BSD-3-Clause
//
// Library-level benchmark driver for go-ruby-benchmark/benchmark.
//
// Benchmark's whole job is to MEASURE elapsed time, so timing its wall-clock
// measurement would be non-deterministic and meaningless to compare. Instead we
// benchmark the module's DETERMINISTIC, pure functions over FIXED Tms values:
// memberwise Tms arithmetic, default- and custom-format rendering, and the bm
// table row/caption formatting. The inputs are fixed, so every runtime produces
// byte-identical output — verified against MRI before any timing (run with the
// single argument "emit" to print that canonical output).
package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/go-ruby-benchmark/benchmark"
)

// Fixed operands, identical to the Ruby driver and to the library's own MRI
// oracle test — so the formatted output is reproducible and byte-comparable.
var (
	a = benchmark.NewTms(2.0, 4.0, 1.0, 0.5, 8.0, "a")
	b = benchmark.NewTms(1.0, 1.0, 0.5, 0.25, 2.0, "b")
	t = benchmark.NewTms(1.0, 2.0, 0.5, 0.25, 3.5, "lbl")

	// Fixed rows for the report-table op (as if produced by a fixed clock).
	r1 = benchmark.NewTms(0.100000, 0.050000, 0.025000, 0.012500, 1.000000, "for:")
	r2 = benchmark.NewTms(0.200000, 0.100000, 0.050000, 0.025000, 2.000000, "times:")

	// Report offset: MRI's Benchmark.bm(7) uses label_width+1 = 8.
	rep = benchmark.NewReport(nil, 8, "")

	customFmt = "%n %u %y %t %r %%"
)

// reportTable renders the caption plus one row per fixed Tms, exactly as
// Benchmark#benchmark lays out a bm table given those Tms values.
func reportTable() string {
	var sb strings.Builder
	sb.WriteString(rep.Caption())
	sb.WriteString(rep.Line(r1))
	sb.WriteString(rep.Line(r2))
	return sb.String()
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "emit" {
		emit()
		return
	}
	bench("tms-arith", 2000, func() {
		sink = a.Add(b)
		sink = a.Sub(b)
		sink = a.Mul(b)
		sink = a.Div(b)
	})
	bench("tms-format-default", 2000, func() {
		sink = t.ToS()
	})
	bench("tms-format-custom", 2000, func() {
		sink = t.Format(customFmt)
	})
	bench("report-table", 1000, func() {
		sink = reportTable()
	})
}

// emit prints the canonical, deterministic output of every op, for byte-exact
// comparison against the Ruby driver's `emit` before timing.
func emit() {
	fmt.Print("== tms-arith ==\n")
	fmt.Print(a.Add(b).Format(""))
	fmt.Print(a.Sub(b).Format(""))
	fmt.Print(a.Mul(b).Format(""))
	fmt.Print(a.Div(b).Format(""))
	fmt.Print("== tms-format-default ==\n")
	fmt.Print(t.ToS())
	fmt.Print("== tms-format-custom ==\n")
	fmt.Print(t.Format(customFmt))
	fmt.Print("\n")
	fmt.Print("== report-table ==\n")
	fmt.Print(reportTable())
}
