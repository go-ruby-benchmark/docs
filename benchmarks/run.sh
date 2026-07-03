#!/usr/bin/env bash
#
# Copyright (c) the go-ruby-* authors
# SPDX-License-Identifier: BSD-3-Clause
#
# Library-level cross-runtime benchmark runner for go-ruby-benchmark/benchmark.
#
# Runs the SAME deterministic workload through (a) the pure-Go library
# (benchmarks/go) and (b) each available reference Ruby runtime
# (benchmarks/ruby/benchmark.rb), then prints one Markdown table per
# sub-benchmark: ns/op and the ratio vs MRI.
#
# Before timing, it VERIFIES that the Go driver and MRI produce byte-identical
# canonical output (the "emit" mode) — the numbers only mean something once the
# implementations are proven to agree.
#
# Usage:  bash benchmarks/run.sh
# Env:    OUTER (timed passes, default 25), WARM (untimed passes, default 3),
#         RUBY / JRUBY / TRUFFLERUBY (override runtime binaries).
set -u
cd "$(dirname "$0")"

RUBY=${RUBY:-ruby}
JRUBY=${JRUBY:-jruby}
TRUFFLERUBY=${TRUFFLERUBY:-truffleruby}

RB=$(ls ruby/*.rb | grep -v _harness | head -1)
MOD=$(basename "$RB" .rb)
export GOWORK=off

# --- Byte-parity gate: Go emit must equal MRI emit before any timing. ---------
echo "== verifying go output == MRI (byte-identical) ==" >&2
GO_EMIT=$( cd go && go run . emit )
MRI_EMIT=$( "$RUBY" "$RB" emit )
if [ "$GO_EMIT" != "$MRI_EMIT" ]; then
  echo "FATAL: go output != MRI output; refusing to time divergent impls" >&2
  diff <(printf '%s' "$MRI_EMIT") <(printf '%s' "$GO_EMIT") >&2 || true
  exit 1
fi
echo "  ok: go and MRI agree byte-for-byte" >&2

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

run() { # <runtime-label> <cmd...>
  local label=$1; shift
  command -v "$1" >/dev/null 2>&1 || { echo "  ($label: $1 not found — skipped)" >&2; return; }
  echo "  $label ..." >&2
  "$@" 2>/dev/null | awk -v r="$label" '$1=="RESULT"{printf "%s\t%s\t%s\n", r, $2, $3}' >> "$TMP"
}

echo "== go-ruby-$MOD library-level benchmark ==" >&2
echo "  go ..." >&2
( cd go && command -v go >/dev/null 2>&1 && go run . 2>/dev/null ) \
  | awk '$1=="RESULT"{printf "go\t%s\t%s\n", $2, $3}' >> "$TMP"
run "mri"         "$RUBY"                "$RB"
run "mri-yjit"    "$RUBY" --yjit        "$RB"
run "jruby"       "$JRUBY"              "$RB"
run "truffleruby" "$TRUFFLERUBY"        "$RB"

echo >&2
# Emit one Markdown table per sub-benchmark (label), runtimes as rows.
awk -F'\t' '
  { key=$2; rt=$1; ns=$3; labels[key]=1; val[rt SUBSEP key]=ns; rts[rt]=1 }
  END {
    order="go mri mri-yjit jruby truffleruby"
    n=split(order, ord, " ")
    ln=0; for (k in labels) lab[++ln]=k
    for (i=1;i<=ln;i++) for (j=i+1;j<=ln;j++) if (lab[j]<lab[i]){t=lab[i];lab[i]=lab[j];lab[j]=t}
    for (i=1;i<=ln;i++){
      k=lab[i]
      printf "\n#### %s\n\n", k
      print  "| Runtime | ns/op | vs MRI |"
      print  "| --- | ---: | ---: |"
      base=val["mri" SUBSEP k]
      for (o=1;o<=n;o++){
        rt=ord[o]; v=val[rt SUBSEP k]
        if (v=="") continue
        ratio=(base!=""&&base+0>0)? sprintf("%.2fx", v/base) : "-"
        name=rt
        if (rt=="go") name="**go-ruby (pure Go)**"
        else if (rt=="mri") name="MRI"
        else if (rt=="mri-yjit") name="MRI + YJIT"
        else if (rt=="jruby") name="JRuby"
        else if (rt=="truffleruby") name="TruffleRuby"
        printf "| %s | %s | %s |\n", name, v, ratio
      }
    }
  }
' "$TMP"
