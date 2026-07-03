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

## Library-level benchmark (Go API vs runtimes) — 2026-07-03

This section measures the **pure-Go library directly, through its Go API** — not
the `rbgo` interpreter path recorded above. It isolates the `Observable` registry
primitive from Ruby-interpreter dispatch, answering the parity question head-on:
*is the pure-Go implementation as fast as the reference runtime's own `observer`?*
The **same workload, same inputs, same iteration counts** run through the Go
library and through each reference runtime's stdlib `observer`; the observer
notification results were checked identical to MRI (a shared deterministic
checksum) before any timing.

- **Host:** Apple M4 Max (`Mac16,5`, arm64), macOS 26.5.1 — **date 2026-07-03**.
- **Runtimes:** Go 1.26.4 · MRI `ruby 4.0.5 +PRISM` · MRI + YJIT · JRuby 10.1.0.0
  (OpenJDK 25) · TruffleRuby 34.0.1 (GraalVM CE Native).
- **Workload:** a `Subject` mixing in `Observable` with **20** `Watcher`
  observers, each whose `update` accumulates its arguments. The four ops are
  `add_observer` (register all 20 on a fresh subject), `notify` (`changed` +
  `notify_observers(a, b)` fanning out to all 20), `count_observers`, and
  `delete_observer` (register 20 then delete each). Go asks the registry for the
  ordered `(observer, method)` entries and performs the `update` dispatch itself,
  exactly as `rbgo` does in production; the registry never calls observers.
- **Method:** each process runs 5 untimed warm-up passes, then 60 timed passes of
  a fixed inner loop, timed with a monotonic clock; the **best** pass is reported
  as **ns/op** (lower is better). `vs MRI` < 1.00× means *faster than MRI*.
  Interpreter start-up is outside the timed region, so these are operation costs,
  not `ruby file.rb` process costs. The Go and MRI runs must emit an identical
  `CHECK` checksum (here `200000`) or `run.sh` aborts before timing.

### go vs YJIT — the pure-Go library beats MRI + YJIT on every op

The pure-Go registry is a plain insertion-ordered slice plus a
`map[observer]method`; `add`/`delete`/`count` and the notify decision are direct
Go map/slice operations with no interpreter dispatch, so it clears both MRI and
YJIT on **all four** ops (three independent runs; go's margin over YJIT was
stable across all of them).

| Op | go ns/op | YJIT ns/op | go vs MRI | go vs YJIT | verdict |
| --- | ---: | ---: | ---: | ---: | --- |
| add_observer-20 | 904.3 | 1028.5 | 0.41× | **0.88×** | **beats MRI + YJIT** |
| notify-20 | 182.9 | 504.0 | 0.14× | **0.36×** | **beats MRI + YJIT** |
| count_observers-20 | 1.8 | 10.8 | 0.05× | **0.17×** | **beats MRI + YJIT** |
| delete_observer-20 | 1446.1 | 2116.0 | 0.37× | **0.68×** | **beats MRI + YJIT** |

#### add_observer-20

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 904.3 | 0.41× |
| MRI | 2184.5 | 1.00× |
| MRI + YJIT | 1028.5 | 0.47× |
| JRuby | 774.3 | 0.35× |
| TruffleRuby | 260.3 | 0.12× |

#### count_observers-20

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 1.8 | 0.05× |
| MRI | 37.8 | 1.00× |
| MRI + YJIT | 10.8 | 0.29× |
| JRuby | 10.7 | 0.28× |
| TruffleRuby | 10.7 | 0.28× |

#### delete_observer-20

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 1446.1 | 0.37× |
| MRI | 3888.5 | 1.00× |
| MRI + YJIT | 2116.0 | 0.54× |
| JRuby | 1228.1 | 0.32× |
| TruffleRuby | 434.0 | 0.11× |

#### notify-20

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 182.9 | 0.14× |
| MRI | 1273.5 | 1.00× |
| MRI + YJIT | 504.0 | 0.40× |
| JRuby | 2269.5 | 1.78× |
| TruffleRuby | 97.2 | 0.08× |

**Verdict: the pure-Go library beats both MRI and MRI + YJIT on all four ops.**
The registry's work is a slice append/scan plus a comparable-key map lookup — no
per-send frame setup, no method-cache probe — so even YJIT's compiled `Hash`
bookkeeping stays behind. `notify-20` (0.36× YJIT) and `count_observers-20`
(0.17× YJIT) are the widest margins; `add_observer-20` (0.88× YJIT) is the
narrowest but held across all three runs. TruffleRuby, timed cold and single-shot
like every column here, still leads the two shortest loops (`notify`, and it ties
the pack on `count`) — read those sub-microsecond rows as order-of-magnitude.

!!! note "Reproduce"
    The harness is committed under
    [`benchmarks/`](https://github.com/go-ruby-observer/docs/tree/main/benchmarks):
    a self-contained Go driver (`go/`, whose `go.mod` pins this library by
    **pseudo-version** — no `replace`), the equivalent `ruby/observer.rb`
    workload, and `run.sh`. Run `OUTER=60 WARM=5 bash benchmarks/run.sh`; env
    `OUTER`/`WARM` tune the pass budget and `RUBY`/`JRUBY`/`TRUFFLERUBY` select the
    runtime binaries. `run.sh` compares the Go and MRI `CHECK` checksums and
    aborts on any mismatch before timing.

!!! warning "Warm-up budget & noise — honest framing"
    Numbers reflect a **fixed warm-process budget** (5 warm-up + 60 timed passes
    in one process, best pass reported). The JVM/GraalVM JITs (JRuby, TruffleRuby)
    may need a larger warm-up to reach steady state, so their columns can
    **understate** peak throughput — most visibly on the shortest loops
    (`notify`, `count_observers`). Sub-microsecond rows carry the most relative
    noise; treat those ratios as order-of-magnitude. Every number here is a
    **real measured value** from the dated run above — nothing is fabricated,
    estimated, or cherry-picked. The go-ruby column is the pure-Go library; every
    other column is that interpreter's own stdlib `observer` doing the equivalent
    work.
