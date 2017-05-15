## Collisions for various geometric shapes. Supports rectangles, triangles,
## circles and polygons. Also includes procedures for checking if a point is
## within any of the supported shapes.
##
## There are three kinds of procedures for each shape; within, collides, and
## collision. Within takes a point and a shape to check against. Collides takes
## two shapes and returns a boolean, this is typically faster than the collision
## procedure as it can terminate early. Collision also takes two shapes but
## returns the smallest rectangle which contains the entire overlap.
##
## The helper function bound is also available to return the smallest rectangle
## encompassing all the points given to it. There is also a direction function
## that takes two rectangles and returns a Direction enum value.


# Collides implemented for:
# Triangle -> Triangle
# Triangle -> Circle
# Rectangle -> Triangle
# Rectangle -> Circle
# Rectangle -> Rectangle
# Infinite line -> Circle
# Circle -> Circle
# Rectangle -> Polygon
# Triangle -> Polygon
# Circle -> Polygon
# Polygon -> Polygon
#
# Collision implemented for:
# Line -> Line (intersect)
# Line -> Circle (intersect)
# Rectangle -> Rectangle
# Rectangle -> Circle
# Rectangle -> Triangle
# Triangle -> Triangle
# Triangle -> Circle
# Circle -> Circle
# Rectangle -> Polygon
# Triangle -> Polygon
# Circle -> Polygon
# Polygon -> Polygon

import sdl2
import math

type
  Direction* {.pure.} = ## Compass directions that explains how two rectangles
    ## overlap. North means that either the two top corners are covered, or
    ## that no corners are covered and the only intersection is within the top
    ## line of the rectangle. North-east means that only the top-left corner is
    ## covered. The other directions work the same way.
    enum north, northeast, east, southeast, south, southwest, west, northwest, none

proc direction*(rect1, rect2: Rect): Direction =
  ## Takes two rectangles and returns a Direction enum type.
  result =
    if rect2.x == rect1.x:
      if rect2.y == rect1.y:
        if rect2.w != rect1.w:
          if rect2.h != rect1.h:
            Direction.northwest
          else:
            Direction.west
        else:
          if rect2.h != rect1.h:
            Direction.north
          else:
            Direction.none
      else:
        if rect2.w != rect1.w:
          if rect2.y+rect2.h != rect1.y+rect1.h:
            Direction.west
          else:
            Direction.southwest
        else:
          Direction.south
    else:
      if rect2.h == rect1.h:
        Direction.east
      else:
        if rect2.y > rect1.y:
          if rect2.y+rect2.h != rect1.y+rect1.h:
            if rect2.x+rect2.w == rect1.x+rect1.w:
              Direction.east
            else:
              Direction.none
          else:
            if rect2.x+rect2.w != rect1.x+rect1.w:
              Direction.south
            else:
              Direction.southeast
        else:
          if rect2.x+rect2.w != rect1.x+rect1.w:
            Direction.north
          else:
            Direction.northeast

proc bound*(points: varargs[Point]): ref Rect =
  ## Takes a variable amount of points and returns the smallest Rect that
  ## contains all points.
  new result
  result.x = cint.high
  result.y = cint.high
  for point in points:
    result.x = min(result.x, point.x)
    result.y = min(result.y, point.y)
  for point in points:
    result.w = max(result.w, point.x-result.x)
    result.h = max(result.h, point.y-result.y)

proc bound*(points: seq[Point]): ref Rect =
  ## Takes a sequence of points and returns the smallest Rect that contains all
  ## points.
  new result
  result.x = cint.high
  result.y = cint.high
  for point in points:
    result.x = min(result.x, point.x)
    result.y = min(result.y, point.y)
  for point in points:
    result.w = max(result.w, point.x-result.x)
    result.h = max(result.h, point.y-result.y)
  #return rect(x,y,w,h)

proc within*(point: Point, centre: Point, radius: int): bool =
  ## Checks if the point is within the circle.
  if sqrt((centre.x-point.x).float.pow(2)+(centre.y-point.y).float.pow(2)).cint < radius:
    return true
  return false

proc within*(point, tri1v1, tri1v2, tri1v3: Point): bool =
  ## Checks if the point is within the trangle formed by the three last points.
  let alpha = ((tri1v2.y - tri1v3.y)*(point.x - tri1v3.x) + (tri1v3.x - tri1v2.x)*(point.y - tri1v3.y)) / ((tri1v2.y - tri1v3.y)*(tri1v1.x - tri1v3.x) + (tri1v3.x - tri1v2.x)*(tri1v1.y - tri1v3.y))
  if 0 < alpha:
    let beta = ((tri1v3.y - tri1v1.y)*(point.x - tri1v3.x) + (tri1v1.x - tri1v3.x)*(point.y - tri1v3.y)) / ((tri1v2.y - tri1v3.y)*(tri1v1.x - tri1v3.x) + (tri1v3.x - tri1v2.x)*(tri1v1.y - tri1v3.y))
    if 0 < beta:
      if 0 < 1 - alpha - beta:
        return true
  return false

proc within*(point: Point, rect: Rect): bool=
  ## Checks if the point is within the given rectangle
  if
    (point.x>rect.x and point.x<rect.x+rect.w) and
    (point.y>rect.y and point.y<rect.y+rect.h):
      return true
  return false

# Point in polygon implementation from here: http://geomalgorithms.com/a03-_inclusion.html

# isLeft(): tests if a point is Left|On|Right of an infinite line.
#    Input:  three points P0, P1, and P2
#    Return: >0 for P2 left of the line through P0 and P1
#            =0 for P2  on the line
#            <0 for P2  right of the line
proc isLeft( P0, P1, P2: Point ): int {.inline.} =
  return ( (P1.x - P0.x) * (P2.y - P0.y) - (P2.x -  P0.x) * (P1.y - P0.y) )

# wn_PnPoly(): winding number test for a point in a polygon
#      Input:   P = a point,
#               V[] = vertex points of a polygon V[n+1] with V[n]=V[0]
#      Return:  wn = the winding number (=0 only when P is outside)
proc wn_PnPoly( P: Point, V:seq[Point] ): int =
  var wn:int = 0    # the  winding number counter

  # loop through all edges of the polygon
  for i in 0..<V.high:                        # edge from V[i] to  V[i+1]
    if (V[i].y <= P.y):                     # start y <= P.y
      if (V[i+1].y  > P.y):                 # an upward crossing
        if (isLeft( V[i], V[i+1], P) > 0):  # P left of  edge
          wn+=1                             # have  a valid up intersect
    else:                                   # start y > P.y (no test needed)
      if (V[i+1].y  <= P.y):                # a downward crossing
        if (isLeft( V[i], V[i+1], P) < 0):  # P right of  edge
          wn-=1                             # have  a valid down intersect
  return wn

proc within*(point: Point, polygon: seq[Point]): bool =
  ## Checks if the point is within the polygon created by a sequence of points.
  ## The sequence should NOT have polygon[0]==polygon[polygon.high]
  var V = polygon
  V.add V[0]
  return wn_PnPoly(point, V) != 0

proc intersection*(line1Start, line1End, line2Start, line2End: Point): ref Point =
  ## Returns the point in which the two line segments intersect or nil if there
  ## is no intersection.
  let
    A1 = line1End.y-line1Start.y
    B1 = line1Start.x-line1End.x
    C1 = A1*line1Start.x+B1*line1Start.y
    A2 = line2End.y-line2Start.y
    B2 = line2Start.x-line2End.x
    C2 = A2*line2Start.x+B2*line2Start.y
    det = A1*B2 - A2*B1
  if det != 0:
    let
      x = ((B2*C1 - B1*C2)/det).cint
      y = ((A1*C2 - A2*C1)/det).cint
    if min(line1Start.x,line1End.x) <= x and
      x <= max(line1Start.x,line1End.x) and
      min(line2Start.x,line2End.x) <= x and
      x <= max(line2Start.x,line2End.x) and
      min(line1Start.y,line1End.y) <= y and
      y <= max(line1Start.y,line1End.y) and
      min(line2Start.y,line2End.y) <= y and
      y <= max(line2Start.y,line2End.y) :
      new result
      result.x = x
      result.y = y
      return result
  return nil

proc intersection*(lineStart, lineEnd: Point, centre: Point, radius: int): seq[Point] =
  ## Returns a sequence of zero, one, or two points of intersection between a
  ## line segment and a circle.
  let
    startCentered = point(lineStart.x-centre.x,lineStart.y-centre.y)
    endCentered = point(lineEnd.x-centre.x,lineEnd.y-centre.y)
  proc sign(x: int): int =
    (x > 0).int - (x < 0).int
  let
    dx = endCentered.x-startCentered.x
    dy = endCentered.y-startCentered.y
    dr = sqrt(dx.float.pow(2)+dy.float.pow(2))
    D = startCentered.x*endCentered.y-endCentered.x*startCentered.y
    disc = radius.float.pow(2)*dr.float.pow(2)-D.float.pow(2)
  if disc >= 0:
    let
      ix = sign(dy).float*dx.float*sqrt(disc)
      iy = abs(dy).float*sqrt(disc)
    if disc == 0:
      let
        x = ((D.float*dy.float+ix)/dr.pow(2)).cint
        y = ((-D.float*dx.float+iy)/dr.pow(2)).cint
      if min(startCentered.x,endCentered.x) <= x and
        x <= max(startCentered.x,endCentered.x) and
        min(startCentered.y,endCentered.y) <= y and
        y <= max(startCentered.y,endCentered.y):
          return @[point(x+centre.x,y+centre.y)]
    else:
      let
        x1 = ((D.float*dy.float+ix)/dr.pow(2)).cint
        x2 = ((D.float*dy.float-ix)/dr.pow(2)).cint
        y1 = ((-D.float*dx.float+iy)/dr.pow(2)).cint
        y2 = ((-D.float*dx.float-iy)/dr.pow(2)).cint
      result = @[]
      if min(startCentered.x,endCentered.x) <= x1 and
        x1 <= max(startCentered.x,endCentered.x) and
        min(startCentered.y,endCentered.y) <= y1 and
        y1 <= max(startCentered.y,endCentered.y):
        result.add point(x1+centre.x,y1+centre.y)
      if min(startCentered.x,endCentered.x) <= x2 and
        x2 <= max(startCentered.x,endCentered.x) and
        min(startCentered.y,endCentered.y) <= y2 and
        y2 <= max(startCentered.y,endCentered.y):
        result.add point(x2+centre.x,y2+centre.y)

proc collides*(tri1v1, tri1v2, tri1v3, tri2v1, tri2v2, tri2v3: Point): bool =
  ## Checks if the two triangles created by the six points intersects with each
  ## other.
  for l1 in [(tri1v1,tri1v2),(tri1v2,tri1v3),(tri1v3,tri1v1)]:
    for l2 in [(tri2v1,tri2v2),(tri2v2,tri2v3),(tri2v3,tri2v1)]:
      if intersection(l1[0],l1[1],l2[0],l2[1]) != nil:
        return true
  if tri2v1.within(tri1v1, tri1v2, tri1v3):
    return true
  if tri1v1.within(tri2v1, tri2v2, tri2v3):
    return true
  return false

proc collides*(rect: Rect, tri1v1, tri1v2, tri1v3: Point): bool =
  ## Checks if the given rectangle and the triangle created by the three points
  ## intersects with each other.
  for l1 in  [(point(rect.x,rect.y),point(rect.x+rect.w,rect.y)),(point(rect.x+rect.w,rect.y),point(rect.x+rect.w,rect.y+rect.h)),(point(rect.x+rect.w,rect.y+rect.h),point(rect.x,rect.y+rect.h)),(point(rect.x,rect.y+rect.h),point(rect.x,rect.y))]:
    for l2 in [(tri1v1,tri1v2),(tri1v2,tri1v3),(tri1v3,tri1v1)]:
      if intersection(l1[0],l1[1],l2[0],l2[1]) != nil:
        return true
  if tri1v1.within rect:
    return true
  if point(rect.x, rect.y).within(tri1v1, tri1v2, tri1v3):
    return true
  return false


proc collides*(rect: Rect, centre: Point, radius: cint): bool =
  ## Checks if the given rectangle intersects with the circle given by the
  ## centre and a radius.
  let
    x1 = sqrt(abs(radius.float.pow(2)-((rect.y+rect.h)-centre.y).float.pow(2))).cint
    x2 = sqrt(abs(radius.float.pow(2)-(rect.y-centre.y).float.pow(2))).cint
    y1 = sqrt(abs(radius.float.pow(2)-((rect.x+rect.w)-centre.x).float.pow(2))).cint
    y2 = sqrt(abs(radius.float.pow(2)-(rect.x-centre.x).float.pow(2))).cint

  let h =
    if not (centre.x>rect.x and centre.x<rect.x+rect.w):
      if centre.x>rect.x:
        y1
      else:
        y2
    else:
      radius

  let w =
    if not (centre.y>rect.y and centre.y<rect.y+rect.h):
      if centre.y>rect.y:
        x1
      else:
        x2
    else:
      radius
  let
    xpw = if centre.x+w > rect.x+rect.w: rect.x+rect.w else: centre.x+w
    xmw = if centre.x-w < rect.x: rect.x else: centre.x-w
    yph = if centre.y+h > rect.y+rect.h: rect.y+rect.h else: centre.y+h
    ymh = if centre.y-h < rect.y: rect.y else: centre.y-h
  if xmw < rect.x+rect.w and xpw > rect.x and ymh < rect.y+rect.h and yph > rect.y:
    return true
  return false

proc collides*(rect1, rect2: Rect): bool =
  ## Checks if the two given rectangles intersects with each other.
  let
    x1inx2 = (rect1.x>rect2.x and rect1.x<rect2.x+rect2.w)
    x2inx1 = (rect2.x>rect1.x and rect2.x<rect1.x+rect1.w)
    y1iny2 = (rect1.y>rect2.y and rect1.y<rect2.y+rect2.h)
    y2iny1 = (rect2.y>rect1.y and rect2.y<rect1.y+rect1.h)
  if
    (x1inx2 or x2inx1) and
    (y1iny2 or y2iny1):
      return true
  return false

proc collides*(rect: Rect, polygon: seq[Point]): bool =
  ## Checks if the rectangle and the polygon described by the sequence of points
  ## intersects with each other. The sequence should NOT have
  ## polygon[0]==polygon[polygon.high]
  for i in 0..polygon.high:
    for line in  [(point(rect.x,rect.y),point(rect.x+rect.w,rect.y)),(point(rect.x+rect.w,rect.y),point(rect.x+rect.w,rect.y+rect.h)),(point(rect.x+rect.w,rect.y+rect.h),point(rect.x,rect.y+rect.h)),(point(rect.x,rect.y+rect.h),point(rect.x,rect.y))]:
        if intersection(polygon[i],polygon[(i+1) mod polygon.high],line[0],line[1]) != nil:
          return true
  for p in polygon:
    if p.within(rect):
      return true
  for p in [point(rect.x,rect.y),point(rect.x+rect.w,rect.y),point(rect.x+rect.w,rect.y+rect.h),point(rect.x,rect.y+rect.h)]:
    if p.within(polygon):
      return true

proc collides*(tri1v1, tri1v2, tri1v3: Point, polygon: seq[Point]): bool =
  ## Checks if the triangle given by the three first points intersects with the
  ## polygon described by the sequence of points. The sequence should NOT have
  ## polygon[0]==polygon[polygon.high]
  for i in 0..polygon.high:
    for line in [(tri1v1,tri1v2),(tri1v2,tri1v3),(tri1v3,tri1v1)]:
        if intersection(polygon[i],polygon[(i+1) mod polygon.high],line[0],line[1]) != nil:
          return true
  for p in polygon:
    if p.within(tri1v1,tri1v2,tri1v3):
      return true
  for p in [tri1v1,tri1v2,tri1v3]:
    if p.within(polygon):
      return true

proc collides*(polygon1: seq[Point], polygon2: seq[Point]): bool =
  ## Checks if the two polygons described by the two sequences of points
  ## intersects. The sequences should NOT have polygon[0]==polygon[polygon.high]
  for i in 0..polygon1.high:
    for j in 0..polygon2.high:
        if intersection(polygon1[i],polygon1[(i+1) mod polygon1.high],polygon2[j],polygon2[(j+1) mod polygon2.high]) != nil:
          return true
  for p in polygon1:
    if p.within(polygon2):
      return true
  for p in polygon2:
    if p.within(polygon1):
      return true

proc collides*(centre: Point, radius: int, polygon: seq[Point]): bool =
  ## Checks if the circle described by the centre point and the radius and the
  ## polygon described by the sequence of points intersects. The sequence
  ## should NOT have polygon[0]==polygon[polygon.high]
  for i in 0..polygon.high:
    if intersection(polygon[i],polygon[(i+1) mod polygon.high],centre, radius).len > 0:
      return true
  if centre.within(polygon):
    return true
  for p in polygon:
    if p.within(centre, radius):
      return true

proc collides*(triv1,triv2,triv3: Point, centre: Point, radius: int): bool =
  ## Checks if the triangle given by the three points intersects with the circle
  ## given by the centre point and the radius.
  for line in [(triv1,triv2),(triv2,triv3),(triv3,triv1)]:
    if intersection(line[0],line[1],centre,radius).len > 0:
      return true
  if triv1.within(centre,radius):
    return true
  if centre.within(triv1,triv2,triv3):
    return true

proc collides*(centre1: Point, radius1: int, centre2: Point, radius2: int): bool =
  ## Checks if the two circles given by the two centres and the two radii
  ## intersects.
  let d = sqrt((centre1.x-centre2.x).float.pow(2)+(centre1.y-centre2.y).float.pow(2)).cint
  if d < radius1+radius2:
    return true

proc collision*(tri1v1, tri1v2, tri1v3, tri2v1, tri2v2, tri2v3: Point): ref Rect =
  ## Checks if the two triangles created by the six points intersects with each
  ## other and returns the smallest rectangle that contains the collision.
  var intersections: seq[Point] = @[]
  for l1 in [(tri1v1,tri1v2),(tri1v2,tri1v3),(tri1v3,tri1v1)]:
    for l2 in [(tri2v1,tri2v2),(tri2v2,tri2v3),(tri2v3,tri2v1)]:
      let intersection = intersection(l1[0],l1[1],l2[0],l2[1])
      if intersection != nil:
        intersections.add intersection[]
  for p in [tri2v1, tri2v2, tri2v3]:
    if p.within(tri1v1, tri1v2, tri1v3):
      intersections.add p
  for p in [tri1v1, tri1v2, tri1v3]:
    if p.within(tri2v1, tri2v2, tri2v3):
      intersections.add p
  if intersections.len>0:
    return intersections.bound
  return nil

proc collision*(rect: Rect, tri1v1, tri1v2, tri1v3: Point): ref Rect =
  ## Checks if the given rectangle and the triangle created by the three points
  ## intersects with each other and returns the smallest rectangle that
  ## contains the collision.
  var intersections: seq[Point] = @[]
  for l1 in  [(point(rect.x,rect.y),point(rect.x+rect.w,rect.y)),(point(rect.x+rect.w,rect.y),point(rect.x+rect.w,rect.y+rect.h)),(point(rect.x+rect.w,rect.y+rect.h),point(rect.x,rect.y+rect.h)),(point(rect.x,rect.y+rect.h),point(rect.x,rect.y))]:
    for l2 in [(tri1v1,tri1v2),(tri1v2,tri1v3),(tri1v3,tri1v1)]:
      let intersection = intersection(l1[0],l1[1],l2[0],l2[1])
      if intersection != nil:
        intersections.add intersection[]
  for p in [tri1v1, tri1v2, tri1v3]:
    if p.within rect:
      intersections.add p
  for p in [point(rect.x,rect.y),point(rect.x+rect.w,rect.y),point(rect.x+rect.w,rect.y+rect.h),point(rect.x,rect.y+rect.h)]:
    if p.within(tri1v1, tri1v2, tri1v3):
      intersections.add p
  if intersections.len>0:
    return intersections.bound
  return nil

proc collision*(rect: Rect, centre: Point, radius: cint): ref Rect =
  ## Checks if the given rectangle intersects with the circle given by the
  ## centre and a radius and returns the smallest rectangle that contains the
  ## collision.
  let
    x1 = sqrt(abs(radius.float.pow(2)-((rect.y+rect.h)-centre.y).float.pow(2))).cint
    x2 = sqrt(abs(radius.float.pow(2)-(rect.y-centre.y).float.pow(2))).cint
    y1 = sqrt(abs(radius.float.pow(2)-((rect.x+rect.w)-centre.x).float.pow(2))).cint
    y2 = sqrt(abs(radius.float.pow(2)-(rect.x-centre.x).float.pow(2))).cint

  let h =
    if not (centre.x>rect.x and centre.x<rect.x+rect.w):
      if centre.x>rect.x:
        y1
      else:
        y2
    else:
      radius

  let w =
    if not (centre.y>rect.y and centre.y<rect.y+rect.h):
      if centre.y>rect.y:
        x1
      else:
        x2
    else:
      radius
  let
    xpw = if centre.x+w > rect.x+rect.w: rect.x+rect.w else: centre.x+w
    xmw = if centre.x-w < rect.x: rect.x else: centre.x-w
    yph = if centre.y+h > rect.y+rect.h: rect.y+rect.h else: centre.y+h
    ymh = if centre.y-h < rect.y: rect.y else: centre.y-h
  if xmw < rect.x+rect.w and xpw > rect.x and ymh < rect.y+rect.h and yph > rect.y:
    new result
    result.x = xmw
    result.y = ymh
    result.w = xpw - xmw
    result.h = yph - ymh
  else:
    return nil

proc collision*(rect1, rect2: Rect): ref Rect =
  ## Checks if the two given rectangles intersects with each other and returns
  ## the smallest rectangle that contains the collision.
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
        result.x = rect2.x
        result.w = rect1.x+rect1.w-rect2.x
        if result.w > rect2.w:
          result.w = rect2.w
      else:
        result.x = rect1.x
        result.w = rect2.x+rect2.w-rect1.x
        if result.w > rect1.w:
          result.w = rect1.w
      if y2iny1:
        result.y = rect2.y
        result.h = rect1.y+rect1.h-rect2.y
        if result.h > rect2.h:
          result.h = rect2.h
      else:
        result.y = rect1.y
        result.h = rect2.y+rect2.h-rect1.y
        if result.h > rect1.h:
          result.h = rect1.h
      return result
  return nil

proc collision*(rect: Rect, polygon: seq[Point]): ref Rect =
  ## Checks if the rectangle and the polygon described by the sequence of points
  ## intersects with each other and returns the smallest rectangle that
  ## contains the collision. The sequence should NOT have
  ## polygon[0]==polygon[polygon.high].
  var intersections: seq[Point] = @[]
  for i in 0..polygon.high:
    for line in  [(point(rect.x,rect.y),point(rect.x+rect.w,rect.y)),(point(rect.x+rect.w,rect.y),point(rect.x+rect.w,rect.y+rect.h)),(point(rect.x+rect.w,rect.y+rect.h),point(rect.x,rect.y+rect.h)),(point(rect.x,rect.y+rect.h),point(rect.x,rect.y))]:
        let intersection = intersection(polygon[i],polygon[(i+1) mod polygon.high],line[0],line[1])
        if intersection != nil:
          intersections.add intersection[]
  for p in polygon:
    if p.within(rect):
      intersections.add p
  for p in [point(rect.x,rect.y),point(rect.x+rect.w,rect.y),point(rect.x+rect.w,rect.y+rect.h),point(rect.x,rect.y+rect.h)]:
    if p.within(polygon):
      intersections.add p
  if intersections.len>0:
    return intersections.bound
  return nil

proc collision*(tri1v1, tri1v2, tri1v3: Point, polygon: seq[Point]): ref Rect =
  ## Checks if the triangle given by the three first points intersects with the
  ## polygon described by the sequence of points and returns the smallest
  ## rectangle that contains the collision. The sequence should NOT have
  ## polygon[0]==polygon[polygon.high]
  var intersections: seq[Point] = @[]
  for i in 0..polygon.high:
    for line in [(tri1v1,tri1v2),(tri1v2,tri1v3),(tri1v3,tri1v1)]:
        let intersection = intersection(polygon[i],polygon[(i+1) mod polygon.high],line[0],line[1])
        if intersection != nil:
          intersections.add intersection[]
  for p in polygon:
    if p.within(tri1v1,tri1v2,tri1v3):
      intersections.add p
  for p in [tri1v1,tri1v2,tri1v3]:
    if p.within(polygon):
      intersections.add p
  if intersections.len>0:
    return intersections.bound
  return nil

proc collision*(polygon1: seq[Point], polygon2: seq[Point]): ref Rect =
  ## Checks if the two polygons described by the two sequences of points
  ## intersects and returns the smallest rectangle that contains the collision.
  ## The sequences should NOT have polygon[0]==polygon[polygon.high]
  var intersections: seq[Point] = @[]
  for i in 0..polygon1.high:
    for j in 0..polygon2.high:
        let intersection = intersection(polygon1[i],polygon1[(i+1) mod polygon1.high],polygon2[j],polygon2[(j+1) mod polygon2.high])
        if intersection != nil:
          intersections.add intersection[]
  for p in polygon1:
    if p.within(polygon2):
      intersections.add p
  for p in polygon2:
    if p.within(polygon1):
      intersections.add p
  if intersections.len>0:
    return intersections.bound
  return nil

proc collision*(centre: Point, radius: int, polygon: seq[Point]): ref Rect =
  ## Checks if the circle described by the centre point and the radius and the
  ## polygon described by the sequence of points intersects and returns the
  ## smallest rectangle that contains the collision. The sequence should NOT
  ## have polygon[0]==polygon[polygon.high]
  var intersections: seq[Point] = @[]
  for i in 0..polygon.high:
    let intersects = intersection(polygon[i],polygon[(i+1) mod polygon.high],centre, radius)
    for intersection in intersects:
      intersections.add intersection
  if centre.within(polygon):
    intersections.add centre
  for p in polygon:
    if p.within(centre, radius):
      intersections.add p
  if intersections.len>0:
    return intersections.bound
  return nil

proc collision*(triv1,triv2,triv3: Point, centre: Point, radius: int): ref Rect =
  ## Checks if the triangle given by the three points intersects with the circle
  ## given by the centre point and the radius and returns the smallest
  ## rectangle that contains the collision.
  var intersections: seq[Point] = @[]
  for line in [(triv1,triv2),(triv2,triv3),(triv3,triv1)]:
    for intersection in intersection(line[0],line[1],centre,radius):
      intersections.add intersection
  for p in [triv1,triv2,triv3]:
    if p.within(centre,radius):
      intersections.add p
  for p in [point(centre.x+radius,centre.y),point(centre.x-radius,centre.y),point(centre.x,centre.y+radius.cint),point(centre.x,centre.y-radius.cint)]:
    if p.within(triv1,triv2,triv3):
      intersections.add p
  if intersections.len>0:
    return intersections.bound

proc collision*(centre1: Point, radius1: int, centre2: Point, radius2: int): ref Rect =
  ## Checks if the two circles given by the two centres and the two radii
  ## intersects and returns the smallest rectangle that contains the collision.
  let d = sqrt((centre1.x-centre2.x).float.pow(2)+(centre1.y-centre2.y).float.pow(2)).cint
  if d > radius1+radius2:
    return nil
  if d < abs(radius1-radius2):
    if radius1<radius2:
      new result
      result.x = (centre1.x-radius1).cint
      result.y = (centre1.y-radius1).cint
      result.w = radius1.cint*2
      result.h = radius1.cint*2
    else:
      new result
      result.x = (centre2.x-radius2).cint
      result.y = (centre2.y-radius2).cint
      result.w = radius2.cint*2
      result.h = radius2.cint*2
  else:
    let
      a = (radius1.float.pow(2) - radius2.float.pow(2) + d.float.pow(2) ) / (2*d).float
      h = sqrt(radius1.float.pow(2) - a.pow(2))
      x2 = centre1.x.float + a*(( centre2.x - centre1.x )/d)
      y2 = centre1.y.float + a*(( centre2.y - centre1.y )/d)
      pmx = h*(centre2.y - centre1.y ).float / d.float
      pmy = h*(centre2.x - centre1.y ).float / d.float
      x31 = x2 + pmx
      y31 = y2 - pmy
      x32 = x2 - pmx
      y32 = y2 + pmy
    var intersections = @[point(x31,y31),point(x32,y32)]
    for p in [point(centre2.x+radius2.cint,centre2.y),point(centre2.x-radius2.cint,centre2.y),point(centre2.x,centre2.y+radius2.cint),point(centre2.x,centre2.y-radius2.cint)]:
      if p.within(centre1,radius1):
        intersections.add p
    if intersections.len>0:
      return intersections.bound
