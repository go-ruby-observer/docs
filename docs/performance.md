# Performance

`go-ruby-observer/observer` is the pure-Go library that
[`rbgo`](https://github.com/go-embedded-ruby/ruby) binds for Ruby's `Observable`
registry. This page records the **methodology** for the comparative benchmark of
that module against the reference Ruby runtimes, part of the ecosystem-wide
per-module parity suite.

!!! note "No numbers published here yet"
    This page documents *how* the `observer` row is measured. The measured
    figures are produced by running the harness below and are not reproduced here
    until they have been captured on the reference host — no placeholder or
    estimated numbers are recorded.

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
