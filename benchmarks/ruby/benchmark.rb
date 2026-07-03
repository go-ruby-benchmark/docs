# frozen_string_literal: true
# SPDX-License-Identifier: BSD-3-Clause
#
# Ruby-side workload for the go-ruby-benchmark library-level benchmark.
#
# Benchmark MEASURES elapsed time, so timing its wall-clock measurement is meta
# and non-deterministic. We instead exercise the module's DETERMINISTIC parts
# over FIXED Tms values: memberwise Tms arithmetic, default- and custom-format
# rendering, and the bm table row/caption formatting. Fixed inputs mean every
# runtime prints byte-identical output, verified against MRI before timing
# (run with the single argument "emit" to print that canonical output).
require "benchmark"
require_relative "_harness"

# Fixed operands, identical to the Go driver and the library's MRI oracle test.
A = Benchmark::Tms.new(2.0, 4.0, 1.0, 0.5, 8.0, "a")
B = Benchmark::Tms.new(1.0, 1.0, 0.5, 0.25, 2.0, "b")
T = Benchmark::Tms.new(1.0, 2.0, 0.5, 0.25, 3.5, "lbl")

# Fixed rows for the report-table op (as if produced by a fixed clock).
R1 = Benchmark::Tms.new(0.100000, 0.050000, 0.025000, 0.012500, 1.000000, "for:")
R2 = Benchmark::Tms.new(0.200000, 0.100000, 0.050000, 0.025000, 2.000000, "times:")

WIDTH = 8 # Benchmark.bm(7) offsets labels by label_width + 1 = 8.
CUSTOM_FMT = "%n %u %y %t %r %%"

# report_table renders the caption plus one row per fixed Tms, exactly as
# Benchmark#benchmark lays out a bm table given those Tms values.
def report_table
  out = +(" " * WIDTH) << Benchmark::CAPTION
  out << R1.label.ljust(WIDTH) << R1.format
  out << R2.label.ljust(WIDTH) << R2.format
  out
end

def emit
  print "== tms-arith ==\n"
  print (A + B).format, (A - B).format, (A * B).format, (A / B).format
  print "== tms-format-default ==\n"
  print T.to_s
  print "== tms-format-custom ==\n"
  print T.format(CUSTOM_FMT)
  print "\n"
  print "== report-table ==\n"
  print report_table
end

if ARGV[0] == "emit"
  emit
else
  sink = nil
  bench("tms-arith", 2000) do
    sink = A + B
    sink = A - B
    sink = A * B
    sink = A / B
  end
  bench("tms-format-default", 2000) { sink = T.to_s }
  bench("tms-format-custom",  2000) { sink = T.format(CUSTOM_FMT) }
  bench("report-table",       1000) { sink = report_table }
  sink
end
