################################################################################
# NinePatch is a special format for scalable bitmaps. It uses guides drawn into
# the image to tell a program which regions are able to scale and which are
# not, with optional guides on where in the scaled image content should be
# drawn. This is a support class for the TextureAtlas which needs to take the
# arguments decoded from the image directly. In the future this will also
# include the means to load a NinePatch image directly. Note that the NinePatch
# has two different render functions, one that renders the NinePatch to fill a
# region (regular render), the other to render it around a region
# (renderForRegion). 
################################################################################

import sdl2

type
  NinePatch* = ref object
    texture*: TexturePtr
    size*: Rect
    splitColumns: array[0..2,cint]
    splitRows: array[0..2,cint]
    pad: Lengths
    offset*: Point
    region*: Rect
    rotated*: bool

  Lengths* = tuple[left,top,right,bottom: cint]

proc lengths*(left,top,right,bottom: cint): Lengths =
  result.left = left
  result.top = top
  result.right = right
  result.bottom = bottom

proc newNinePatch*(texture: TexturePtr, region: Rect, size: Rect, offset: Point, rotated: bool, split: Lengths, pad: Lengths): NinePatch =
  new result
  result.texture = texture
  result.size = size
  result.offset = offset
  result.rotated = rotated
  result.region = region
  result.splitColumns[0] = split.left
  result.splitColumns[1] = region.w - split.left - split.right
  result.splitColumns[2] = split.right
  result.splitRows[0] = split.top
  result.splitRows[1] = region.h - split.top - split.bottom
  result.splitRows[2] = split.bottom
  result.pad = pad

proc render*(renderer: RendererPtr, ninepatch: NinePatch, x,y,w,h: cint, alpha:uint8 = 255) =
  var
    src,dst: Rect
    scW, scH: cint = 0
    dcW, dcH: cint = 0
    growX = w - ninepatch.region.w
    growY = h - ninepatch.region.h
    col, row = 0
  ninepatch.texture.setTextureAlphaMod(alpha)
  for c in ninepatch.splitColumns:
    for r in ninepatch.splitRows:
      src = rect(ninepatch.region.x+scW,ninepatch.region.y+scH,c,r)
      dst = rect (x+dcW,y+dcH,c+(if col == 1: growX else: 0),r+(if row == 1: growY else: 0))
      renderer.copyEx(ninepatch.texture,
        src,
        dst,
        angle = if ninepatch.rotated: 90.0 else: 0.0,
        center = nil,
        flip = SDL_FLIP_NONE)
      scH += r
      dcH += r + (if row == 1: growY else: 0)
      row += 1
    scW += c
    dcW += c + (if col == 1: growX else: 0)
    col += 1
    row = 0
    scH = 0
    dcH = 0
  ninepatch.texture.setTextureAlphaMod(255)

template render*(renderer: RendererPtr, ninepatch: NinePatch, region:Rect, alpha:uint8 = 255) =
  renderer.render(ninepatch,region.x,region.y,region.w,region.h,alpha)

template renderForRegion*(renderer: RendererPtr, ninepatch: NinePatch, x,y,w,h: cint, alpha:uint8 = 255) =
  renderer.render(ninepatch,x-ninepatch.pad.left,y-ninepatch.pad.top,w+ninepatch.pad.left+ninepatch.pad.right,h+ninepatch.pad.top+ninepatch.pad.bottom,alpha)

template renderForRegion*(renderer: RendererPtr, ninepatch: NinePatch, region:Rect, alpha:uint8 = 255) =
  renderer.render(ninepatch,region.x-ninepatch.pad.left,region.y-ninepatch.pad.top,region.w+ninepatch.pad.left+ninepatch.pad.right,region.h+ninepatch.pad.top+ninepatch.pad.bottom,alpha)
