// SPDX-License-Identifier: BSD-3-Clause
package main

import (
	"fmt"

	"github.com/go-ruby-observer/observer"
)

// N is the number of observers registered on the subject, matching observer.rb.
const N = 20

// watcher is a Go observer whose update accumulates its arguments, so a fixed
// changed+notify sequence produces a deterministic checksum shared with the Ruby
// side. A *watcher is comparable, so it is usable directly as an observer key.
type watcher struct{ total int }

func (w *watcher) update(a, b int) { w.total += a + b }

// respondUpdate mirrors MRI's respond_to?(:update) gate that Observable#add_observer
// applies: it lets AddObserver reproduce MRI's NoMethodError path, so the Go
// add_observer does the same responsiveness check the reference runtime does.
func respondUpdate(_ observer.Observer, name string) bool { return name == observer.DefaultFunc }

// dispatch performs the notification exactly as rbgo does in production: it asks
// the registry for the ordered (observer, method) entries and invokes update on
// each with the echoed arguments. The registry never calls observers itself.
func dispatch(reg *observer.Registry, a, b int) {
	reg.Changed(true)
	entries, args, ok := reg.NotifyObservers(a, b)
	if !ok {
		return
	}
	x, y := args[0].(int), args[1].(int)
	for _, e := range entries {
		if e.Func == observer.DefaultFunc {
			e.Observer.(*watcher).update(x, y)
		}
	}
}

// checksum registers n observers, runs a fixed changed+notify sequence, and sums
// every observer's accumulator. It must equal the Ruby checksum before timing.
func checksum(n int) int {
	ws := make([]*watcher, n)
	for i := range ws {
		ws[i] = &watcher{}
	}
	var reg observer.Registry
	for _, w := range ws {
		_ = reg.AddObserver(w, observer.DefaultFunc, respondUpdate)
	}
	for i := 0; i < 100; i++ {
		dispatch(&reg, i, i+1)
	}
	sum := 0
	for _, w := range ws {
		sum += w.total
	}
	return sum
}

func main() {
	fmt.Printf("CHECK\t%d\n", checksum(N))

	watchers := make([]*watcher, N)
	for i := range watchers {
		watchers[i] = &watcher{}
	}

	// subj is preloaded with N observers, reused by notify and count benchmarks.
	var subj observer.Registry
	for _, w := range watchers {
		_ = subj.AddObserver(w, observer.DefaultFunc, respondUpdate)
	}

	// add_observer: register N observers on a fresh registry.
	bench("add_observer-20", 2000, func() {
		var reg observer.Registry
		for _, w := range watchers {
			_ = reg.AddObserver(w, observer.DefaultFunc, respondUpdate)
		}
		sink = reg.CountObservers()
	})

	// notify: mark changed and fan out to all N observers.
	bench("notify-20", 2000, func() {
		dispatch(&subj, 3, 4)
	})

	// count_observers: read the registered-observer count.
	bench("count_observers-20", 20000, func() {
		sink = subj.CountObservers()
	})

	// delete_observer: register N then delete each of them.
	bench("delete_observer-20", 2000, func() {
		var reg observer.Registry
		for _, w := range watchers {
			_ = reg.AddObserver(w, observer.DefaultFunc, respondUpdate)
		}
		for _, w := range watchers {
			reg.DeleteObserver(w)
		}
		sink = reg.CountObservers()
	})
}
