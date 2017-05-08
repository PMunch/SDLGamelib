################################################################################
# Tweens are a wrapper around Bezier curves to make it easy to ease between
# values. There are three tween types included here, Tween which has a float
# between 0 and 1. TweenValue which takes two floats to ease between and eases
# between them. And a TweenSeq which takes two sequences of values to ease
# between.
#
# A tool such as http://cubic-bezier.com/ can be used to generate easing curves.
# You can also use the first 25 easing curves found here: http://easings.net/
# directly by calling the initTween procuderes with EaseFunction.<ease>.
#
# The code for the Bezier curves were copied from:
# https://github.com/gre/bezier-easing and rewritten to Nim. This work is
# licensed under the MIT License and it's original copyright comment is
# included below.
################################################################################

#[/**
 * https://github.com/gre/bezier-easing
 * BezierEasing - use bezier curve for transition easing function
 * by Gaëtan Renaudeau 2014 - 2015 – MIT License
 */]#

import tables

type
  Tween* = ref object
    BezierEasing: proc(x: float): float
    t: float

  TweenValue* = ref object
    BezierEasing: proc(x: float): float
    t: float
    fromValue: float
    ratio: float

  TweenSeq* = ref object
    BezierEasing: proc(x: float): float
    t: float
    fromValues: seq[float]
    ratios: seq[float]

  EaseFunction* {.pure.} = enum
    linear, easeInSine, easeOutSine, easeInOutSine,
    easeInQuad, easeOutQuad, easeInOutQuad,
    easeInCubic, easeOutCubic, easeInOutCubic,
    easeInQuart, easeOutQuart, easeInOutQuart,
    easeInQuint, easeOutQuint, easeInOutQuint,
    easeInExpo, easeOutExpo, easeInOutExpo,
    easeInCirc, easeOutCirc, easeInOutCirc,
    easeInBack, easeOutBack, easeInOutBack

const easeFunctions = {
  EaseFunction.linear: (0.0,0.0,1.0,1.0),
  EaseFunction.easeInSine: (0.47, 0.0, 0.745, 0.715),
  EaseFunction.easeOutSine: (0.39, 0.575, 0.565, 1.0),
  EaseFunction.easeInOutSine: (0.445, 0.05, 0.55, 0.95),
  EaseFunction.easeInQuad: (0.55, 0.085, 0.68, 0.53),
  EaseFunction.easeOutQuad: (0.25, 0.46, 0.45, 0.94),
  EaseFunction.easeInOutQuad: (0.455, 0.03, 0.515, 0.955),
  EaseFunction.easeInCubic: (0.55, 0.055, 0.675, 0.19),
  EaseFunction.easeOutCubic: (0.215, 0.61, 0.355, 1.0),
  EaseFunction.easeInOutCubic: (0.645, 0.045, 0.355, 1.0),
  EaseFunction.easeInQuart: (0.895, 0.03, 0.685, 0.22),
  EaseFunction.easeOutQuart: (0.165, 0.84, 0.44, 1.0),
  EaseFunction.easeInOutQuart: (0.77, 0.0, 0.175, 1.0),
  EaseFunction.easeInQuint: (0.755, 0.05, 0.855, 0.06),
  EaseFunction.easeOutQuint: (0.23, 1.0, 0.32, 1.0),
  EaseFunction.easeInOutQuint: (0.86, 0.0, 0.07, 1.0),
  EaseFunction.easeInExpo: (0.95, 0.05, 0.795, 0.035),
  EaseFunction.easeOutExpo: (0.19, 1.0, 0.22, 1.0),
  EaseFunction.easeInOutExpo: (1.0, 0.0, 0.0, 1.0),
  EaseFunction.easeInCirc: (0.6, 0.04, 0.98, 0.335),
  EaseFunction.easeOutCirc: (0.075, 0.82, 0.165, 1.0),
  EaseFunction.easeInOutCirc: (0.785, 0.135, 0.15, 0.86),
  EaseFunction.easeInBack: (0.6, -0.28, 0.735, 0.045),
  EaseFunction.easeOutBack: (0.175, 0.885, 0.32, 1.275),
  EaseFunction.easeInOutBack: (0.68, -0.55, 0.265, 1.55)
}.toTable



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

proc getBezierEasing(mX1, mY1, mX2, mY2: float): proc(x: float): float  =
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

  return proc (x:float): float =
    if mX1 == mY1 and mX2 == mY2:
      return x #// linear

    #// Because JavaScript number are imprecise, we should guarantee the extremes are right.
    if x == 0:
      return 0
    if x == 1:
      return 1

    return calcBezier(getTForX(x), mY1, mY2)

template initTween*(ease: EaseFunction): Tween =
  let easeParams = easeFunctions[ease]
  initTween(easeParams[0],easeParams[1],easeParams[2],easeParams[3])

proc initTween*(mX1, mY1, mX2, mY2: float): Tween =
  new result
  result.BezierEasing = getBezierEasing(mX1, mY1, mX2, mY2)

proc tick*(tween: Tween or TweenValue or TweenSeq, tickLength: float) =
  tween.t += tickLength

proc value*(tween: Tween): float =
  return tween.BezierEasing(tween.t)

template initTweenValue*(fromValue, toValue:float , ease: EaseFunction): TweenValue =
  let easeParams = easeFunctions[ease]
  initTweenValue(fromValue, toValue, easeParams[0],easeParams[1],easeParams[2],easeParams[3])

proc initTweenValue*(fromValue, toValue, mX1, mY1, mX2, mY2: float): TweenValue =
  new result
  result.fromValue = fromValue
  result.ratio = toValue-fromValue
  result.BezierEasing = getBezierEasing(mX1, mY1, mX2, mY2)

proc value*(tween: TweenValue): float =
  return tween.fromValue + tween.BezierEasing(tween.t)*tween.ratio

template initTweenValues*(fromValues: seq[float], toValues: seq[float], ease: EaseFunction): TweenSeq =
  let easeParams = easeFunctions[ease]
  initTweenValues(fromValues, toValues, easeParams[0],easeParams[1],easeParams[2],easeParams[3])

proc initTweenValues*(fromValues: seq[float], toValues: seq[float], mX1, mY1, mX2, mY2: float): TweenSeq =
  if fromValues.len != toValues.len:
    raise newException(ValueError, "fromValues and toValues much be of the same length")
  new result
  result.fromValues = fromValues
  result.ratios = @[]
  for i in 0..fromValues.high:
    result.ratios.add toValues[i]-fromValues[i]
  result.BezierEasing = getBezierEasing(mX1, mY1, mX2, mY2)

proc values*(tween: TweenSeq): seq[float] =
  result = @[]
  let ratio = tween.BezierEasing(tween.t)
  for i in 0..(tween.fromValues).high:
    result.add tween.fromValues[i] + ratio*tween.ratios[i]
