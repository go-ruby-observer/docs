# go-ruby-observer documentation

**Ruby's `Observable` mixin — the observer registry and changed flag — in pure Go, MRI-compatible, no cgo.**

`go-ruby-observer/observer` is a faithful, pure-Go (zero cgo) reimplementation of
the core state behind Ruby's **`Observable`** mixin: the observer **registry** and
the **changed** flag, as specified by MRI's `lib/observer.rb` and verified against
the reference interpreter (Ruby 4.0.5) with `ruby -robserver`. The module path is
`github.com/go-ruby-observer/observer`.

A `Registry` backs one object that includes `Observable`. It **owns** the ordered
set of observers (insertion order, as MRI's Hash-keyed store), the changed-flag
lifecycle, and the notify decision/reset. It deliberately **does not invoke
observers**: `NotifyObservers` returns the ordered `(observer, method)` tuples to
call, and the actual `update` **dispatch stays in the embedding interpreter** —
in [go-embedded-ruby](https://github.com/go-embedded-ruby/ruby), `rbgo` performs
it, binding this module as a native module just like
[go-ruby-regexp](https://github.com/go-ruby-regexp) and
[go-ruby-erb](https://github.com/go-ruby-erb). Responsiveness (`respond_to?`) is
delegated to a caller-supplied callback, so the package has **no dependency on
any interpreter**.

!!! success "Status: complete — MRI-faithful"
    The full `Observable` registry surface — `AddObserver` / `DeleteObserver` / `DeleteObservers` / `CountObservers` / `Changed` / `ChangedQ` / `NotifyObservers` — with insertion-order notification, the re-add-keeps-position rule, the `*NotRespondingError` carrying MRI's verbatim message, and the no-op-when-unchanged / notify-then-reset lifecycle. Verified against the system `ruby -robserver` at 100% coverage, `gofmt` + `go vet` clean, CI green across the six 64-bit Go targets and three OSes.

## Quick taste

```go
import "github.com/go-ruby-observer/observer"

var r observer.Registry

// add_observer(w)  /  add_observer(w2, :special)
_ = r.AddObserver(w, observer.DefaultFunc, respondTo)
_ = r.AddObserver(w2, "special", respondTo)

r.Changed(true) // changed
entries, args, ok := r.NotifyObservers("event")
if ok {
    for _, e := range entries {
        dispatch(e.Observer, e.Func, args) // rbgo invokes e.Func on e.Observer
    }
}
// r.ChangedQ() == false now
```

## The MRI mapping

| MRI `Observable` | this package |
| --- | --- |
| `add_observer(obj, func=:update)` | `Registry.AddObserver` |
| `delete_observer(obj)` | `Registry.DeleteObserver` |
| `delete_observers` | `Registry.DeleteObservers` |
| `count_observers` | `Registry.CountObservers` |
| `changed(state=true)` | `Registry.Changed` |
| `changed?` | `Registry.ChangedQ` |
| `notify_observers(*args)` | `Registry.NotifyObservers` |

## Repositories

| Repo | What it is |
| --- | --- |
| [`observer`](https://github.com/go-ruby-observer/observer) | the library — the `Observable` registry and changed flag in pure Go |
| [`docs`](https://github.com/go-ruby-observer/docs) | this documentation site (MkDocs Material, versioned with mike) |
| [`go-ruby-observer.github.io`](https://github.com/go-ruby-observer/go-ruby-observer.github.io) | the organization landing page (Hugo) |
| [`brand`](https://github.com/go-ruby-observer/brand) | logo and brand assets |

## Principles

- **Pure Go, `CGO_ENABLED=0`** — trivial cross-compilation, a single static
  binary, no C toolchain.
- **Owns the registry, not the dispatch.** The package owns the observer set,
  insertion ordering, the changed-flag lifecycle and the notify decision; the
  `update` dispatch onto each observer stays in the consumer (rbgo).
- **MRI-faithful.** Insertion-order notification, the verbatim
  ``observer does not respond to `update'`` message, and the
  no-op-when-unchanged / reset-after-notify lifecycle, validated against the
  reference interpreter.
- **100% test coverage** is the target, enforced as a CI gate, across 6 arches
  and 3 OSes.

## Where to go next

- [Why pure Go](why.md) — why the registry state is deterministic enough to live
  as a standalone, interpreter-independent Go library.
- [Usage & API](api.md) — the public surface and worked examples.
- [Roadmap](roadmap.md) — what is done and what is downstream by design.

Source lives at [github.com/go-ruby-observer/observer](https://github.com/go-ruby-observer/observer).
