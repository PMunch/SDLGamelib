################################################################################
# A ticker keeps a collection of elements with an associated tick function and
# allows them to be ticked all by the same procedure call.
#
# The ticker also keeps track of the time by itself and such doesn't require to
# be called with a tickLength value. However a version of the tick function
# exists that overrides the tickLength in order to allow the tickers to be
# nested. This is practical for things like particle effects where all the
# particles can be put in a single ticker (which is then added to the main
# ticker) and then be deleted all at once when the effect is over.
#
# Tickers can also be set on pause which means that they won't call the tick
# procedures but will still keep track of time. This is to stop elements from
# trying to catch up after a pause where they were meant to be frozen.
################################################################################

import times

type
  Tickable = concept x
    tick(x, float)

  TickProc* = proc (tickLength: float)

  TickNode* = ref object
    ticker: TickProc
    next: TickNode

  Ticker = ref object
    ticks, last: TickNode
    lastTick: float
    paused*: bool

iterator items(ticker:TickNode):TickProc =
  var t = ticker
  while t!=nil:
    yield t.ticker
    t = t.next

iterator nodes(ticker:TickNode):TickNode =
  var t = ticker
  while t!=nil:
    yield t
    t = t.next

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
  result.ticks = nil
  result.lastTick = epochTime()
  result.paused = false

proc add*(ticker: Ticker, tickable: Tickable): TickNode =
  return ticker.ticks.add(proc(tickLength: float) =
    tickable.tick(tickLength))

proc add*(ticker: Ticker, tick: TickProc): TickNode =
  var newNode = TickNode(ticker: tick, next: nil)
  ticker.last.next = newNode
  ticker.last = newNode
  return newNode

proc delete*(ticker: Ticker, tickNode: TickNode) =
  var lastTick: TickNode = nil
  for tick in ticker.ticks.nodes:
    if tick == tickNode:
      lastTick.next = tick.next
      if tickNode == ticker.last:
        ticker.last = lastTick
      if tickNode == ticker.ticks:
        ticker.ticks = tick.next
      return
    lastTick = tick
