#!/usr/bin/env bash
#
# Copyright (c) the go-ruby-* authors
# SPDX-License-Identifier: BSD-3-Clause
#
# Library-level cross-runtime benchmark runner.
#
# Runs the SAME workload through (a) the pure-Go go-ruby library (benchmarks/go)
# and (b) each available reference Ruby runtime (benchmarks/ruby/<mod>.rb), then
# prints one Markdown table per sub-benchmark: ns/op and the ratio vs MRI.
#
# Before timing, the Go driver's CHECK checksum is compared against MRI's; a
# mismatch aborts the run, so the numbers are only ever reported for identical
# observer-notification results.
#
# Usage:  bash benchmarks/run.sh
# Env:    OUTER (timed passes, default 25), WARM (untimed passes, default 3),
#         RUBY / JRUBY / TRUFFLERUBY (override runtime binaries).
set -u
cd "$(dirname "$0")"
export GOWORK=off

RUBY=${RUBY:-ruby}
JRUBY=${JRUBY:-jruby}
TRUFFLERUBY=${TRUFFLERUBY:-truffleruby}

RB=$(ls ruby/*.rb | grep -v _harness | head -1)
MOD=$(basename "$RB" .rb)
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

check_of() { awk '$1=="CHECK"{print $2; exit}'; }

echo "== go-ruby-$MOD library-level benchmark ==" >&2

# Correctness gate: Go output must equal MRI before any timing is recorded.
GO_OUT=$( cd go && WARM=0 OUTER=1 go run . 2>/dev/null )
MRI_OUT=$( WARM=0 OUTER=1 "$RUBY" "$RB" 2>/dev/null )
GO_CHK=$(printf '%s\n' "$GO_OUT" | check_of)
MRI_CHK=$(printf '%s\n' "$MRI_OUT" | check_of)
if [ -z "$GO_CHK" ] || [ "$GO_CHK" != "$MRI_CHK" ]; then
  echo "  ABORT: checksum mismatch (go='$GO_CHK' mri='$MRI_CHK')" >&2
  exit 1
fi
echo "  checksum OK: go == mri == $GO_CHK" >&2

run() { # <runtime-label> <cmd...>
  local label=$1; shift
  command -v "$1" >/dev/null 2>&1 || { echo "  ($label: $1 not found — skipped)" >&2; return; }
  echo "  $label ..." >&2
  "$@" 2>/dev/null | awk -v r="$label" '$1=="RESULT"{printf "%s\t%s\t%s\n", r, $2, $3}' >> "$TMP"
}

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
        ratio=(base!=""&&base+0>0)? sprintf("%.2f×", v/base) : "—"
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
