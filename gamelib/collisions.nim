################################################################################
# Rudimentary collision functions to check for collision between two
# rectangles, or a rectangle and a circle. More types of collisions will be
# added in the future.
#
# The Collision type consists of the smallest rectangle that contains the entire
# collision and a direction. The direction is given in compass units and gives
# an idea of which direction the collision occured in. They are always going
# from the first passed object to the second.
#
# In case the direction is not of interest the check could be sped up slightly
# by passing the `withdirection` flag as false. This is a static flag and will
# compile away the direction calculation. Something similar might be added for
# the encompassing rectangle as well.
################################################################################

import sdl2
import math

type
  Direction* {.pure.} = enum north, northeast, east, southeast, south, southwest, west, northwest, none

  Collision* = ref object
    rect*: Rect
    direction*: Direction

proc collides*(rect1: Rect, point: Point, radius: cint, withdirection: static[bool] = true): Collision =
  let
    x1 = sqrt(abs(radius.float.pow(2)-((rect1.y+rect1.h)-point.y).float.pow(2))).cint
    x2 = sqrt(abs(radius.float.pow(2)-(rect1.y-point.y).float.pow(2))).cint
    y1 = sqrt(abs(radius.float.pow(2)-((rect1.x+rect1.w)-point.x).float.pow(2))).cint
    y2 = sqrt(abs(radius.float.pow(2)-(rect1.x-point.x).float.pow(2))).cint

  let h =
    if not (point.x>rect1.x and point.x<rect1.x+rect1.w):
      if point.x>rect1.x:
        y1
      else:
        y2
    else:
      radius

  let w =
    if not (point.y>rect1.y and point.y<rect1.y+rect1.h):
      if point.y>rect1.y:
        x1
      else:
        x2
    else:
      radius
  let
    xpw = if point.x+w > rect1.x+rect1.w: rect1.x+rect1.w else: point.x+w
    xmw = if point.x-w < rect1.x: rect1.x else: point.x-w
    yph = if point.y+h > rect1.y+rect1.h: rect1.y+rect1.h else: point.y+h
    ymh = if point.y-h < rect1.y: rect1.y else: point.y-h
  if xmw < rect1.x+rect1.w and xpw > rect1.x and ymh < rect1.y+rect1.h and yph > rect1.y:
    new result
    result.rect.x = xmw
    result.rect.y = ymh
    result.rect.w = xpw - xmw
    result.rect.h = yph - ymh
    when withdirection:
      result.direction =
        if result.rect.x == rect1.x:
          if result.rect.y == rect1.y:
            if result.rect.w != rect1.w:
              if result.rect.h != rect1.h:
                Direction.northwest
              else:
                Direction.west
            else:
              if result.rect.h != rect1.h:
                Direction.north
              else:
                Direction.none
          else:
            if result.rect.w != rect1.w:
              if result.rect.y+result.rect.h != rect1.y+rect1.h:
                Direction.west
              else:
                Direction.southwest
            else:
              Direction.south
        else:
          if result.rect.h == rect1.h:
            Direction.east
          else:
            if result.rect.y > rect1.y:
              if result.rect.y+result.rect.h != rect1.y+rect1.h:
                if result.rect.x+result.rect.w == rect1.x+rect1.w:
                  Direction.east
                else:
                  Direction.none
              else:
                if result.rect.x+result.rect.w != rect1.x+rect1.w:
                  Direction.south
                else:
                  Direction.southeast
            else:
              if result.rect.x+result.rect.w != rect1.x+rect1.w:
                Direction.north
              else:
                Direction.northeast
  else:
    return nil

proc collides*(rect1, rect2: Rect, withdirection: static[bool] = true): Collision =
  var rect:Rect
  new result
  let
    x1inx2 = (rect1.x>rect2.x and rect1.x<rect2.x+rect2.w)
    x2inx1 = (rect2.x>rect1.x and rect2.x<rect1.x+rect1.w)
    y1iny2 = (rect1.y>rect2.y and rect1.y<rect2.y+rect2.h)
    y2iny1 = (rect2.y>rect1.y and rect2.y<rect1.y+rect1.h)
  if
    (x1inx2 or x2inx1) and
    (y1iny2 or y2iny1):
      if x2inx1:
        rect.x = rect2.x
        rect.w = rect1.x+rect1.w-rect2.x
        if rect.w > rect2.w:
          rect.w = rect2.w
      else:
        rect.x = rect1.x
        rect.w = rect2.x+rect2.w-rect1.x
        if rect.w > rect1.w:
          rect.w = rect1.w
      if y2iny1:
        rect.y = rect2.y
        rect.h = rect1.y+rect1.h-rect2.y
        if rect.h > rect2.h:
          rect.h = rect2.h
      else:
        rect.y = rect1.y
        rect.h = rect2.y+rect2.h-rect1.y
        if rect.h > rect1.h:
          rect.h = rect1.h
      when withdirection:
        if (rect.h == rect2.h and rect.w == rect2.w) or (rect.h == rect1.h and rect.w == rect1.w):
          result.direction = Direction.none
        else:
          if rect.h == rect1.h or rect.h == rect2.h:
            if (x1inx2 and y1iny2) or (x1inx2 and y2iny1):
              result.direction = Direction.west
            else:
              result.direction = Direction.east
          elif rect.w == rect1.w or rect.w == rect2.w:
            if (x2inx1 and y2iny1) or (x1inx2 and y2iny1):
              result.direction = Direction.south
            else:
              result.direction = Direction.north
          else:
            if x2inx1 and y1iny2:
              result.direction = Direction.northeast
            elif x1inx2 and y1iny2:
              result.direction = Direction.northwest
            elif x2inx1 and y2iny1:
              result.direction = Direction.southeast
            elif x1inx2 and y2iny1:
              result.direction = Direction.southwest

      #echo result.direction
      result.rect = rect
      #return nil
  else:
    return nil
