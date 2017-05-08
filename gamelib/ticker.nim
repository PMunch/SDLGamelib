################################################################################
# A ticker keeps a collection of elements with an associated tick function and
# allows them to be ticked all by the same procedure call.
#
# The ticker also keeps track of the time by itself and such doesn't require to
# be called with a tickLength value. However a version of the tick function
# exists that overrides the tickLength in order to allow the tickers to be
# nested.
#
# Tickers can also be set on pause which means that they won't call the tick
# procedures but will still keep track of time. This is stop elements from
# trying to catch up after a pause where they were meant to be frozen.
################################################################################

import sdl2
import times

type
  Tickable = concept x
    tick(x, float)

  TickProc* = proc (tickLength: float)

  Ticker = ref object
    ticks: seq[TickProc]
    lastTick: float
    paused*: bool

proc tick*(ticker: Ticker) =
  let currentTick = epochTime()
  if not ticker.paused:
    let tickLength = currentTick - ticker.lastTick
    for tick in ticker.ticks:
      tick(tickLength)
  ticker.lastTick = currentTick

proc tick*(ticker: Ticker, tickLength: float) =
  if not ticker.paused:
    for tick in ticker.ticks:
      tick(tickLength)
  ticker.lastTick = epochTime()

proc newTicker*(): Ticker =
  new result
  result.ticks = @[]
  result.lastTick = epochTime()
  result.paused = false

proc add*(ticker: Ticker, tickable: Tickable) =
  ticker.ticks.add proc(tickLength: float) =
    tickable.tick(tickLength)

proc add*(ticker: Ticker, tick: TickProc) =
  ticker.ticks.add tick
