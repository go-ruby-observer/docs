# Contributing

Contributions are welcome. `go-ruby-observer/observer` is built to a small set of non-negotiable
rules — they are what keep it pure-Go, correct, and MRI-compatible. Please read
these before opening a pull request.

## Hard rules

- **Build from source — no vendoring.** Everything compiles from source. Being
  able to compile from source is a guarantee of independence.
- **100% test coverage target, enforced in CI.** New code ships with tests, and
  coverage is a CI gate. Fill the error branches, not just the happy path.
- **All GitHub content in English.** Issues, pull requests, commits, comments,
  and discussions are English-only.
- **Verification against MRI.** Correctness is defined by reference Ruby. The
  registry's observable behaviour is checked against the system `ruby -robserver`
  (Ruby 4.0.5) — insertion order, the changed-flag lifecycle, the
  no-op-when-unchanged / reset-after-notify rule, and the verbatim raise message —
  not approximated from memory.
- **Pure Go, cgo disabled.** The whole point is a single static binary with no C
  toolchain. Code must build with `CGO_ENABLED=0`. If a feature seems to need C,
  it needs a pure-Go path instead.
- **Owns the registry, not the dispatch.** This module owns the observer set,
  ordering, the changed flag and the notify decision. The `update` dispatch and
  anything needing a live Ruby binding belong in the consumer (rbgo), not here.

## Workflow

1. Pick or open an issue describing the change.
2. Work test-first: add the differential / unit tests, then make them pass.
3. Run the full suite with coverage and confirm the gate is green:

    ```sh
    COVERPKG=$(go list ./... | paste -sd, -)
    go test -race -coverpkg="$COVERPKG" -coverprofile=cover.out ./...
    go tool cover -func=cover.out | tail -1   # 100.0%
    ```

4. Open a PR in English, referencing the issue.

## Where things live

The library is in
[`github.com/go-ruby-observer/observer`](https://github.com/go-ruby-observer/observer). This documentation site is in
[`github.com/go-ruby-observer/docs`](https://github.com/go-ruby-observer/docs). Start from the
[Usage & API](api.md) page and the [Roadmap](roadmap.md) to find the right place
for your change.
