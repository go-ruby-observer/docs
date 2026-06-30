# Usage & API

The public API lives at the module root (`github.com/go-ruby-observer/observer`).
It is **Ruby-shaped but Go-idiomatic**: the `Registry` methods mirror
`Observable`'s `add_observer` / `notify_observers` / `changed?` family, while the
surface follows Go conventions — explicit `error` values, an opaque comparable
observer type, no global state.

!!! success "Status: implemented"
    The library is built and importable as `github.com/go-ruby-observer/observer`, bound into `rbgo` as a native module; see [Roadmap](roadmap.md).

## Install

```sh
go get github.com/go-ruby-observer/observer
```

## Worked example

```go
import "github.com/go-ruby-observer/observer"

var r observer.Registry

// add_observer(w)   /   add_observer(w2, :special)
_ = r.AddObserver(w, observer.DefaultFunc, respondTo) // DefaultFunc == "update"
_ = r.AddObserver(w2, "special", respondTo)

r.Changed(true)                                   // changed
entries, args, ok := r.NotifyObservers("event")   // notify_observers("event")
if ok {
    for _, e := range entries {
        // rbgo invokes e.Func on e.Observer with args
        dispatch(e.Observer, e.Func, args)
    }
}
// r.ChangedQ() == false now (notify reset the flag)
```

## Shape

```go
// DefaultFunc is the method Observable#add_observer uses by default (":update").
const DefaultFunc = "update"

// Observer is the opaque, caller-supplied observer value (used as a map key, so
// it must be comparable). Entry pairs an observer with the method to call on it.
type Observer = any
type Entry struct { Observer Observer; Func string }

// RespondTo reports whether observer responds to method name (Ruby respond_to?).
type RespondTo func(observer Observer, name string) bool

// NotRespondingError mirrors the NoMethodError add_observer raises; its Error
// string is MRI's verbatim: observer does not respond to `update'
type NotRespondingError struct { Func string }

// Registry is the state behind one object that includes Observable. The zero
// value is ready: no observers, changed? == false. Not safe for concurrent use
// (matching MRI's Observable).
type Registry struct { /* ... */ }

func (r *Registry) AddObserver(observer Observer, fn string, respondTo RespondTo) error
func (r *Registry) DeleteObserver(observer Observer)
func (r *Registry) DeleteObservers()
func (r *Registry) CountObservers() int
func (r *Registry) Changed(state bool)
func (r *Registry) ChangedQ() bool
func (r *Registry) NotifyObservers(args ...any) (entries []Entry, notifyArgs []any, ok bool)
```

## MRI-faithful semantics

- **Insertion order.** Observers notify in the order they were added (MRI's
  Hash-keyed store). Re-adding an existing observer updates its method and keeps
  its position.
- **`add_observer` of a non-responding method raises.** When the supplied
  `RespondTo` reports false, `AddObserver` returns `*NotRespondingError` with
  MRI's verbatim message ``observer does not respond to `update'`` (rbgo turns it
  into a `NoMethodError`). A `nil` `RespondTo` skips the check.
- **Changed-flag lifecycle.** `changed?` starts false; `Changed(true)` sets it,
  `Changed(false)` clears it.
- **Notify decision/reset.** `NotifyObservers` is a no-op returning `ok == false`
  when `changed?` is false; when changed it returns the observers to call (with
  `args` echoed back unchanged) and then resets `changed?` to false. Use `ok`
  rather than `len(entries)` for the notify decision.

## Relationship to Ruby

`go-ruby-observer/observer` is **standalone and reusable**, and is the backend
bound into [go-embedded-ruby](https://github.com/go-embedded-ruby/ruby) by `rbgo`
as a native module — the same way [go-ruby-regexp](https://github.com/go-ruby-regexp)
and [go-ruby-erb](https://github.com/go-ruby-erb) are bound. The dependency runs
the other way: this library has no dependency on the Ruby runtime, and the
`update` dispatch onto each observer stays in `rbgo`.
