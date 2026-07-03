<!-- SPDX-License-Identifier: BSD-3-Clause -->
# `go-ruby-observer` library-level benchmark harness

Reproducible, cross-runtime benchmark of the **pure-Go `go-ruby-observer/observer`
library** against the reference Ruby runtimes (MRI, MRI + YJIT, JRuby,
TruffleRuby). It measures the **`Observable` registry primitive** through its Go
API — `add_observer` / `notify_observers` / `count_observers` / `delete_observer`
over a fixed set of observers — isolated from the rbgo interpreter, so the numbers
answer: *is the pure-Go implementation as fast as the reference runtime's own
`observer`?*

## Layout

- `go/`               — self-contained Go driver; `go.mod` pins the published
  library by pseudo-version (no `replace`).
- `ruby/observer.rb`  — the equivalent workload; `ruby/_harness.rb` is the shared
  timer.
- `run.sh`            — runs every available runtime and prints one Markdown table
  per sub-benchmark (ns/op + ratio vs MRI).

## Run

```sh
bash benchmarks/run.sh
```

Environment knobs: `OUTER` (timed passes, default 25), `WARM` (untimed warm-up
passes, default 3), and `RUBY`/`JRUBY`/`TRUFFLERUBY` to select runtime binaries.

## Method

Each process runs `WARM` untimed passes (to let the JVM/GraalVM JITs warm up),
then `OUTER` timed passes of a fixed inner loop, timed with a monotonic clock;
the **best** pass is reported as **ns/op**. Interpreter start-up is outside the
timed region. The Go driver and the Ruby script register the **same** 20
observers and run the **same** changed + notify sequence; each prints a
deterministic `CHECK` checksum (the summed observer accumulators) and `run.sh`
**aborts unless the Go checksum equals MRI's** before timing. Results are
published, dated, in `../docs/performance.md`.
