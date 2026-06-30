# Why pure Go

`go-ruby-observer/observer` reimplements the registry behind Ruby's `Observable`
mixin in **pure Go, with cgo disabled**. The slice of Ruby it covers is
**deterministic and interpreter-independent**: the registry's bookkeeping —
*which* observers are registered, in *what order*, the changed flag, and the
decision of *whether* to notify — is a pure function of the calls made to it. No
live binding, no evaluation of arbitrary Ruby. That is exactly the part that can —
and should — live as a standalone Go library, separate from the interpreter.

## Owns the registry, not the dispatch

The clean seam is between **deciding** and **doing**:

- This package **owns** the observer set, insertion ordering, the changed-flag
  lifecycle, and the notify decision/reset. `NotifyObservers` returns the ordered
  `(observer, method)` tuples that *should* be called.
- The host **does** the call: invoking each observer's `update` (or chosen
  method) through the interpreter. In
  [go-embedded-ruby](https://github.com/go-embedded-ruby/ruby), `rbgo` performs
  that dispatch.

Because the dispatch — the one part that needs a live Ruby object and a real
method call — is delegated, the registry itself has **no dependency on any
interpreter**. Responsiveness (`respond_to?`) is likewise injected as a
caller-supplied callback, so even the `add_observer`-raises-on-non-responding
behaviour is reproduced without the package knowing what an interpreter is.

## Why pure Go matters here

Because the library is CGO-free and dependency-free, it:

- cross-compiles to every Go target with no C toolchain, and links into a single
  static binary;
- has **no dependency on the Ruby runtime** — `rbgo` depends on it, not the
  other way around, the same pattern as
  [go-ruby-regexp](https://github.com/go-ruby-regexp) and
  [go-ruby-erb](https://github.com/go-ruby-erb);
- is verified against the system `ruby -robserver` wherever `ruby` is on `PATH`,
  while the cross-arch lanes (where `ruby` is absent) still validate the library
  itself via its deterministic tests.

See [Usage & API](api.md) for the surface and [Roadmap](roadmap.md) for what is
in scope.
