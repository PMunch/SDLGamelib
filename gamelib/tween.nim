## Tweens are a way to ease between values, usefull for smooth motion and
## animations. This module also contains a wrapper around Bezier curves to make
## it easy to ease between values without having to write your own functions.
##
## There are three tween types included here, Tween which has a float
## between 0 and 1. TweenValue which takes two floats to ease between and eases
## between them. And a TweenSeq which takes two sequences of values to ease
## between.
##
## A tool such as http://cubic-bezier.com/ can be used to generate easing
## curves. You can also use the easing curves found here:
## http://easings.net/ directly by calling the initTween procuderes with
## EaseFunction.<ease>.

# The code for the Bezier curves were copied from:
# https://github.com/gre/bezier-easing and rewritten to Nim. This work is
# licensed under the MIT License and it's original copyright comment is
# included below.

#[/**
 * https://github.com/gre/bezier-easing
 * BeazierEasing - use bezier curve for transition easing function
 * by Gaëtan Renaudeau 2014 - 2015 – MIT License
 */]#

import tables
import math

type
  EaseFunction* = ## Type for an EaseFunction that can be used in a Tween.
    ## Takes the time from 0 to the set duration and returns the current state.
    proc(t: float): float

  Tween* = ref object of RootObj
    ## Regular tween object that goes from 0 to 1
    EasingFunction: proc(x: float): float
    cached: bool
    cache: float
    t*: float
    duration*: float

  TweenValue* = ref object of Tween
    ## Tween object that goes from the gives start and stop value
    fromValue: float
    ratio: float

  TweenSeq* = ref object of Tween
    ## Tween object that returns a sequence of float between the two sequences
    fromValues: seq[float]
    ratios: seq[float]

  Ease* {.pure.} = enum
    ## Enum type for the built in easing functions
    linear, InSine, OutSine, InOutSine,
    InQuad, OutQuad, InOutQuad,
    InCubic, OutCubic, InOutCubic,
    InQuart, OutQuart, InOutQuart,
    InQuint, OutQuint, InOutQuint,
    InExpo, OutExpo, InOutExpo,
    InCirc, OutCirc, InOutCirc,
    InBack, OutBack, InOutBack,
    OutBounce, InBounce, InOutBounce
    InElastic, OutElastic, InOutElastic


#// These values are established by empiricism with tests (tradeoff: performance VS precision)
const
  newtonIterations = 4
  newtonMinSlope = 0.001
  subdivisionPrecision = 0.0000001
  subdivisionMaxIterations = 10

  kSplineTableSize = 11
  kSampleStepSize = 1.0 / (kSplineTableSize - 1.0)

proc A (aA1, aA2: float): float = 1.0 - 3.0 * aA2 + 3.0 * aA1
proc B (aA1, aA2: float): float = 3.0 * aA2 - 6.0 * aA1
proc C (aA1: float):float = 3.0 * aA1

#// Returns x(t) given t, x1, and x2, or y(t) given t, y1, and y2.
proc calcBezier (aT, aA1, aA2: float): float = ((A(aA1, aA2) * aT + B(aA1, aA2)) * aT + C(aA1)) * aT

#// Returns dx/dt given t, x1, and x2, or dy/dt given t, y1, and y2.
proc getSlope (aT, aA1, aA2: float): float = 3.0 * A(aA1, aA2) * aT * aT + 2.0 * B(aA1, aA2) * aT + C(aA1)

template doWhile(a: typed, b: untyped): untyped =
  b
  while a:
    b

proc binarySubdivide (aX, aA, aB, mX1, mX2: float): float =
  var
    currentX, currentT, i = 0.0
    aA = aA
    aB = aB
  doWhile((abs(currentX) > subdivisionPrecision) and (i < subdivisionMaxIterations)):
    currentT = aA + (aB - aA) / 2.0
    currentX = calcBezier(currentT, mX1, mX2) - aX
    if currentX > 0.0:
      aB = currentT
    else:
      aA = currentT
    i += 1
  return currentT

proc newtonRaphsonIterate (aX, aGuessT, mX1, mX2: float): float =
  var aGuessT = aGuessT
  for i in 0..<newtonIterations:
    let currentSlope = getSlope(aGuessT, mX1, mX2)
    if currentSlope == 0.0:
      return aGuessT
    let currentX = calcBezier(aGuessT, mX1, mX2) - aX
    aGuessT -= currentX / currentSlope

  return aGuessT

proc getEasingFunction(mX1, mY1, mX2, mY2: float): EaseFunction  =
  if not (0 <= mX1 and mX1 <= 1 and 0 <= mX2 and mX2 <= 1):
    raise newException(ValueError,"Bezier x values must be in [0, 1] range");

  #// Precompute samples table
  var sampleValues: array[kSplineTableSize, float] #float32ArraySupported ? new Float32Array(kSplineTableSize) : new Array(kSplineTableSize);
  if mX1 != mY1 or mX2 != mY2:
    for i in 0..<kSplineTableSize:
      sampleValues[i] = calcBezier(i.float * kSampleStepSize, mX1, mX2)

  proc getTForX (aX: float):float =
    var
      intervalStart = 0.0
      currentSample = 1
      lastSample = kSplineTableSize - 1

    while currentSample != lastSample and sampleValues[currentSample] <= aX:
      intervalStart += kSampleStepSize
      currentSample += 1
    currentSample -= 1

    #// Interpolate to provide an initial guess for t
    var
      dist = (aX - sampleValues[currentSample]) / (sampleValues[currentSample + 1] - sampleValues[currentSample])
      guessForT = intervalStart + dist * kSampleStepSize

    var initialSlope = getSlope(guessForT, mX1, mX2)
    if initialSlope >= newtonMinSlope:
      return newtonRaphsonIterate(aX, guessForT, mX1, mX2)
    elif (initialSlope == 0.0):
      return guessForT
    else:
      return binarySubdivide(aX, intervalStart, intervalStart + kSampleStepSize, mX1, mX2)

  return proc (t:float): float =
    if mX1 == mY1 and mX2 == mY2:
      return t #// linear

    #// Because JavaScript number are imprecise, we should guarantee the extremes are right.
    if t == 0:
      return 0
    if t == 1:
      return 1

    return calcBezier(getTForX(t), mY1, mY2)

var easeFunctions = {
  Ease.linear: EaseFunction(proc(t:float):float = t), #getEasingFunction(0.0,0.0,1.0,1.0),
  Ease.InSine: EaseFunction(proc(t:float):float = 1-sin(PI/2+t*PI/2)),
  Ease.OutSine: EaseFunction(proc(t:float):float = sin(t*PI/2)), #getEasingFunction(0.39, 0.575, 0.565, 1.0),
  Ease.InOutSine: EaseFunction(proc(t:float):float = (1-sin(PI/2+t*PI))/2),
  Ease.InQuad: EaseFunction(proc(t:float):float = pow(t,2)),
  Ease.OutQuad: EaseFunction(proc(t:float):float = t*(2-t)),
  Ease.InOutQuad: EaseFunction(proc(t:float):float =(if t>0.5: 2*t*t else: -1+(4-2*t)*t)),
  Ease.InCubic: EaseFunction(proc(t:float):float = pow(t,3)),
  Ease.OutCubic:  EaseFunction(proc(t:float):float = pow(t-1,3)+1),
  Ease.InOutCubic: EaseFunction(proc(t:float):float =(if t>0.5: 4*pow(t,3) else: (t-1)*pow(2*t-2,2)+1)),
  Ease.InQuart: EaseFunction(proc(t:float):float = pow(t,4)),
  Ease.OutQuart: EaseFunction(proc(t:float):float = 1-pow(t-1,4)),
  Ease.InOutQuart: EaseFunction(proc(t:float):float = (if t<0.5: 8*pow(t,4) else: 1-8*pow(t-1,4))),
  Ease.InQuint: EaseFunction(proc(t:float):float = pow(t,5)),
  Ease.OutQuint: EaseFunction(proc(t:float):float = 1-pow(t-1,5)),
  Ease.InOutQuint: EaseFunction(proc(t:float):float = (if t>0.5: 16*pow(t,5) else: 1+16*pow(t-1,5))),
  Ease.InExpo: EaseFunction(proc(t:float):float = pow(2,10*(t/1-1))),
  Ease.OutExpo: EaseFunction(proc(t:float):float = 1*(-pow(2,-10*t/1)+1)),
  Ease.InOutExpo: EaseFunction(proc(t:float):float = (if t<0.5: 0.5*pow(2,(10 * (t*2 - 1))) else: 0.5*(-pow(2, -10*(t*2-1))+2))),
  Ease.InCirc: EaseFunction(proc(t:float):float = -1*(sqrt(1 - t * t) - 1)),
  Ease.OutCirc: EaseFunction(proc(t:float):float = 1*sqrt(1 - (t-1).pow(2))),
  Ease.InOutCirc: EaseFunction(proc(t:float):float = (if t < 0.5: -0.5*(sqrt(1 - pow(t*2,2)) - 1) else: 0.5*(sqrt(1 - pow(t*2-2,2)) + 1))),
  Ease.InBack: EaseFunction(proc(t:float):float = t * t * ((1.70158 + 1) * t - 1.70158)),
  Ease.OutBack: EaseFunction(proc(t:float):float = 1 * ((t/1 - 1) * (t/2) * ((1.70158 + 1) * (t/2) + 1.70158) + 1)),
  Ease.InOutBack: EaseFunction(proc(t:float):float = (if t<0.5: 0.5*(4*t*t*(3.5949095 * t*2 - 2.5949095)) else: 0.5 * ((t*2 - 2).pow(2) * ((4.9572369875) * (t*2-2) + 3.9572369875) + 2))),
  Ease.OutBounce: EaseFunction(
    proc(t:float):float =
      if t<1/2.75:
        7.5625*t.pow(2)
      elif t<2/2.75:
        7.5625*(t - (1.5 / 2.75)).pow(2) + 0.75
      elif t<2.5/2.75:
        7.5625*(t - (2.25 / 2.75)).pow(2) + 0.9375
      else:
        7.5625*(t - (2.625 / 2.75)).pow(2) + 0.984375
  )
}.toTable
easeFunctions[Ease.InBounce] =
  EaseFunction(
    proc(t:float):float =
      1-easeFunctions[Ease.OutBounce](1 - t)
  )
easeFunctions[Ease.InOutBounce] =
  EaseFunction(
    proc(t:float):float =
      if t<0.5:
        easeFunctions[Ease.InBounce](t*2)*0.5
      else:
        easeFunctions[Ease.OutBounce](t*2-1)*0.5+1*0.5
  )
easeFunctions[Ease.InElastic] =
  EaseFunction(
    proc(t:float):float =
      -(pow(2, 10 * (t - 1))*sin(((t-1) * 1 - 0.075038041) * (2 * PI) / 0.3))
  )
easeFunctions[Ease.OutElastic] =
  EaseFunction(
    proc(t:float):float =
      pow(2, -10 * t) * sin((t * 1 - 0.075038041) * (2 * PI) / 0.3) + 1
  )
easeFunctions[Ease.InOutElastic] =
  EaseFunction(
    proc(t:float):float =
      if t<0.5:
        -0.5*(pow(2, 10 * (t*2 - 1)) * sin(((t*2-1) * 1 - 0.075038041) * (2 * PI) / 0.3))
      else:
        pow(2, -10 * (t*2 - 1)) * sin(((t*2-1) * 1 - 0.075038041) * (2 * PI) / 0.3) * 0.5 + 1
  )
proc initTween*(duration:float, easingFunc: EaseFunction): Tween =
  ## Initialize a new tween with a duration and a custom easing function.
  new result
  result.duration = duration
  result.EasingFunction = easingFunc

template initTween*(duration:float, ease: Ease): Tween =
  ## Initialize a new tween with a duration and a built in ease function
  initTween(duration, easeFunctions[ease])

template initTween*(duration:float, mX1, mY1, mX2, mY2: float): Tween =
  ## Initialize a new tween with a duration and a custom Bezier curve
  initTween(duration, getEasingFunction(mX1, mY1, mX2, mY2))

proc tick*(tween: Tween or TweenValue or TweenSeq, tickLength: float) =
  ## Ticks the tween forward
  if tween.t<tween.duration:
    tween.cached = false
  tween.t += tickLength

proc value*(tween: Tween): float =
  ## Returns the value of a Tween at the current time. NOTE: This caches the
  ## value so calling this multiple times is safe.
  if tween.cached:
    return tween.cache
  if tween.t<tween.duration:
    tween.cache = tween.EasingFunction(tween.t/tween.duration)
  elif tween.t>tween.duration:
    tween.cache = tween.EasingFunction(1)
  tween.cached = true
  return tween.cache

template initTweenValue*(duration:float, fromValue, toValue:float , ease: Ease): TweenValue =
  ## Initialize a new tween with a duration, start value, stop value, and a
  ## built-in easing function.
  initTweenValue(duration, fromValue, toValue, easeFunctions[ease])

proc initTweenValue*(duration: float, fromValue, toValue: float, easingFunc: EaseFunction): TweenValue =
  ## Initialize a new tween with a duration, start value, stop value, and a
  ## custom easing function.
  new result
  result.duration = duration
  result.fromValue = fromValue
  result.ratio = toValue-fromValue
  result.EasingFunction = easingFunc

proc initTweenValue*(duration:float, fromValue, toValue, mX1, mY1, mX2, mY2: float): TweenValue =
  ## Initialize a new tween with a duration, start value, stop value, and a
  ## custom bezier curve.
  initTweenValue(duration, fromValue, toValue, getEasingFunction(mX1, mY1, mX2, mY2))

proc value*(tween: TweenValue): float =
  ## Returns the value of a TweenValue at the current time. NOTE: This caches
  ## the value so calling this multiple times is safe.
  var tweenValue = tween.Tween.value()
  return tween.fromValue + tweenValue*tween.ratio

template initTweenValues*(fromValues: seq[float], toValues: seq[float], ease: Ease): TweenSeq =
  ## Initialize a new tween with a duration, start values, stop values, and a
  ## built-in easing function.
  initTweenValues(fromValues, toValues, easeFunctions[ease])

proc initTweenValues*(fromValues: seq[float], toValues: seq[float], easingFunc: EaseFunction): TweenSeq =
  ## Initialize a new tween with a duration, start values, stop values, and a
  ## custom easing function.
  if fromValues.len != toValues.len:
    raise newException(ValueError, "fromValues and toValues much be of the same length")
  new result
  result.fromValues = fromValues
  result.ratios = @[]
  for i in 0..fromValues.high:
    result.ratios.add toValues[i]-fromValues[i]
  result.EasingFunction = easingFunc

proc initTweenValues*(fromValues: seq[float], toValues: seq[float], mX1, mY1, mX2, mY2: float): TweenSeq =
  ## Initialize a new tween with a duration, start values, stop values, and a
  ## custom bezier curve.
  initTweenValues(fromValues, toValues, getEasingFunction(mX1, mY1, mX2, mY2))

proc values*(tween: TweenSeq,i:int): seq[float] =
  ## Returns the sequence of values of a TweenSeq. NOTE: This caches
  ## the value so calling this multiple times is safe.
  result = @[]
  let ratio = tween.Tween.value()
  for i in 0..(tween.fromValues).high:
    result.add tween.fromValues[i] + ratio*tween.ratios[i]
