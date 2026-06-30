# Roadmap

`go-ruby-observer/observer` is grown **test-first**, each capability verified
against MRI's `Observable` (`ruby -robserver`) rather than built in isolation.
The deterministic, interpreter-independent slice — the observer registry and the
changed flag — is **complete**.

| Stage | What | Status |
| --- | --- | --- |
| Observer registry | A `Registry` backs one object that includes `Observable`: the ordered set of observers (insertion order, as MRI's Hash-keyed store) plus the changed flag. The zero value is ready to use. | **Done** |
| Add / delete / count | `AddObserver`, `DeleteObserver`, `DeleteObservers`, `CountObservers` mirror `add_observer` / `delete_observer` / `delete_observers` / `count_observers`; re-adding an observer updates its method and keeps its position; deleting a non-registered observer is a no-op. | **Done** |
| Changed-flag lifecycle | `Changed(state)` and `ChangedQ()` map to `changed(state=true)` and `changed?`: the flag starts false, is set by `Changed(true)` and cleared by `Changed(false)`. | **Done** |
| Notify decision & reset | `NotifyObservers` is a no-op returning `ok == false` when not changed; when changed it returns the observers in insertion order, each paired with its method, echoes the args, then resets `changed?` to false. | **Done** |
| `respond_to?` & raise semantics | Responsiveness delegated to a caller-supplied `RespondTo`; `AddObserver` of a non-responding method returns `*NotRespondingError` with MRI's verbatim ``observer does not respond to `update'`` message. | **Done** |
| MRI verification & coverage | Behaviour pinned against the system `ruby -robserver` (Ruby 4.0.5); 100% coverage, gofmt + go vet clean, green across all six 64-bit Go arches and three OSes. | **Done** |

## Documented out-of-scope boundaries

These are **deliberate**, recorded so the module's surface is unambiguous:

- **No dispatch.** The package owns the *decision* to notify and the ordered list
  of who to notify; it never invokes an observer's method. The `update` dispatch
  is the consumer's job — that is why `rbgo` binds this module rather than the
  reverse.
- **No responsiveness model.** Whether an observer responds to a method is an
  interpreter concept (`respond_to?`); the package consults an injected callback
  instead of reimplementing it.
- **Not thread-safe by design.** Like MRI's `Observable`, a `Registry` is not
  safe for concurrent use; callers synchronise.
- **Reference is reference Ruby (MRI).** Conformance targets MRI's behaviour, as
  pinned by the verification against `ruby -robserver`.

See [Usage & API](api.md) for the surface and [Why pure Go](why.md) for the
registry/dispatch split.
