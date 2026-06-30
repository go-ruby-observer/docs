# Performance

`go-ruby-observer/observer` is the pure-Go library that
[`rbgo`](https://github.com/go-embedded-ruby/ruby) binds for Ruby's `Observable`
registry. This page records the **methodology** for the comparative benchmark of
that module against the reference Ruby runtimes, part of the ecosystem-wide
per-module parity suite.

## Result (best of 5, ms)

Measured 2026-06-30 on **Apple M4 Max**, macOS (darwin/arm64), Go 1.26.4, with
`ruby 4.0.5 +PRISM`, `jruby 10.1.0.0` (OpenJDK 25) and `truffleruby 34.0.1`
(GraalVM CE Native). The cross-runtime workload registers 32 observers on an
`Observable` subject and fans out `notify_observers` 40 000 times; checksum
identical to MRI before timing.

| Runtime | time | vs MRI |
| --- | ---: | ---: |
| **rbgo** (go-ruby-observer) | 160 | 1.45× |
| MRI (ruby 4.0.5) | 110 | 1.00× |
| MRI + YJIT | 70 | 0.64× |
| JRuby 10.1.0.0 | 1300 | 11.82× |
| TruffleRuby 34.0.1 | 240 | 2.18× |

rbgo runs on **go-ruby-observer** at **~1.5× MRI** (1.45×) — the registry's
per-call bookkeeping (add / changed / the notify decision) is tiny, so the loop is
dominated by the per-observer `update` dispatch, which is rbgo's per-send frame
setup + interface dispatch over MRI's inline-cached interpreter. This is a
sub-250 ms row inside the order-of-magnitude band.

!!! note "Honest framing"
    JRuby and TruffleRuby are timed **cold, single-shot**, so they carry JVM /
    Graal startup on every run — read them as one-shot `ruby file.rb` costs, the
    same way `rbgo` and MRI are measured, not as steady-state JIT numbers. Rows
    under ~250 ms carry the most relative noise; treat the ratio as
    order-of-magnitude. These are **real measured numbers** from the 2026-06-30
    run (Apple M4 Max; `ruby 4.0.5 +PRISM`, `jruby 10.1.0.0`, `truffleruby
    34.0.1`) — nothing is fabricated or cherry-picked.

## What is measured

The **same** Ruby script — an `Observable` workload that registers a set of
observers, marks the subject changed, and calls `notify_observers` so each
observer's `update` runs — is executed under every runtime. `rbgo`'s number
reflects **this pure-Go registry doing the bookkeeping** (add / delete / count /
changed / the notify decision and reset), with the `update` dispatch performed by
the interpreter as in production; every other column is that interpreter's own
stdlib `observer`. So the comparison is the **Ruby-visible operation**,
apples-to-apples across interpreters. The script prints a deterministic checksum
(the observed notification order and counts), and its output is checked
**identical to MRI** before any timing is recorded.

## Method

- **Best-of-N wall time** (best, not mean, to suppress scheduler noise);
  single-shot processes, no warm-up beyond the script's own loop. The host,
  OS/arch and exact runtime versions are recorded alongside the numbers when they
  are published.
- **Runtimes:** MRI (the oracle) and MRI + YJIT; JRuby (on the JVM); TruffleRuby
  (GraalVM). JVM- and Graal-based runtimes are timed **cold, single-shot**, so
  they carry VM startup on every run — they are read as one-shot `ruby file.rb`
  costs, the same way `rbgo` and MRI are measured, not as steady-state JIT
  numbers.

## Reproduce

The benchmark script and harness live in rbgo's repo under
[`bench/modules/`](https://github.com/go-embedded-ruby/ruby/tree/main/bench/modules)
(`observer.rb` + `run.sh`):

```sh
RBGO=./rbgo TRUFFLE=truffleruby bash bench/modules/run.sh 5
```

Because the registry's per-call work is tiny relative to interpreter startup,
treat any ratio for a sub-hundred-millisecond row as order-of-magnitude, and
report the host and runtime versions next to the figures.
