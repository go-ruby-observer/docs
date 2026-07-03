# frozen_string_literal: true
# SPDX-License-Identifier: BSD-3-Clause
require "observer"
require_relative "_harness"

# Subject mixes in the Ruby stdlib Observable module under test.
class Subject
  include Observable
end

# Watcher's #update accumulates its notification arguments, so a fixed
# changed + notify_observers sequence yields a deterministic checksum that the
# Go driver reproduces exactly.
class Watcher
  attr_reader :total

  def initialize
    @total = 0
  end

  def update(a, b)
    @total += a + b
  end
end

N = 20

# Deterministic correctness checksum: register N observers, run a fixed
# changed + notify sequence, and sum every observer's accumulator. Must match Go.
def checksum(n)
  ws = Array.new(n) { Watcher.new }
  s = Subject.new
  ws.each { |w| s.add_observer(w) }
  100.times do |i|
    s.changed
    s.notify_observers(i, i + 1)
  end
  ws.sum(&:total)
end
puts "CHECK\t#{checksum(N)}"

watchers = Array.new(N) { Watcher.new }

# subj is preloaded with N observers, reused by notify and count benchmarks.
subj = Subject.new
watchers.each { |w| subj.add_observer(w) }

# add_observer: register N observers on a fresh subject.
bench("add_observer-20", 2000) do
  s = Subject.new
  watchers.each { |w| s.add_observer(w) }
end

# notify: mark changed and fan out to all N observers.
bench("notify-20", 2000) do
  subj.changed
  subj.notify_observers(3, 4)
end

# count_observers: read the registered-observer count.
bench("count_observers-20", 20000) do
  subj.count_observers
end

# delete_observer: register N then delete each of them.
bench("delete_observer-20", 2000) do
  s = Subject.new
  watchers.each { |w| s.add_observer(w) }
  watchers.each { |w| s.delete_observer(w) }
end
