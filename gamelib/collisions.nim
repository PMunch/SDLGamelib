################################################################################
# Rudimentary collision function to check for collision between two rectangles.
# More types of collisions will be added in the future. The collides function
# takes two sdl2 rects and calculates the intersection between them.
#
#The Collision type consists of this intersecting rectangle and a direction. The
# direction is determined by which corners of the first rect is within the
# corners of the second rect. If the top left corner is within the direction is
# said to be North-West. If the two top corners are within the direction is
# said to be North and so on.
################################################################################

import sdl2

type
  Direction* {.pure.} = enum north, northeast, east, southeast, south, southwest, west, northwest, none

  Collision* = ref object
    rect*: Rect
    direction*: Direction

proc collides*(rect1, rect2: Rect): Collision =
  var rect:Rect
  new result
  let
    x1inx2 = (rect1.x>=rect2.x and rect1.x<=rect2.x+rect2.w)
    x2inx1 = (rect2.x>=rect1.x and rect2.x<=rect1.x+rect1.w)
    y1iny2 = (rect1.y>=rect2.y and rect1.y<=rect2.y+rect2.h)
    y2iny1 = (rect2.y>=rect1.y and rect2.y<=rect1.y+rect1.h)
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
