################################################################################
# A texture region is a simple construct that consists of a texture and a
# region. The region specifies the area in the texture that will be drawn by
# the render funciton. Texture regions are especially practical when dealing
# with animations and texture atlases. This implementation also supports
# textures with regions that are rotated and offset (to accomodate the texture
# atlas). When scaling images the x and y position to render at is the upper
# left corner, when using negative scale the image is simply flipped meaning
# that a negative scale will still draw from x,y to x+w,y+h and not from x,y to
# x-w,y-h as might be expected. The rotation is applied around the center of
# the texture and x and y is located in what would be the top-left corner if it
# weren't rotated. This means that drawing an image at the same x and y while
# changing the rotation will make the sprite rotate in place around it's center.
################################################################################


import sdl2

type
  TextureRegion* = ref object
    texture*: TexturePtr
    region*: Rect
    size*: Rect
    offset*: Point
    rotated*: bool

proc newTextureRegion*(texture: TexturePtr, region: Rect, size: Rect, offset: Point, rotated: bool):TextureRegion =
  new result
  result.texture = texture
  result.region = region
  result.size = size
  result.offset = offset
  result.rotated = rotated

template newTextureRegion*(texture: TexturePtr, region: Rect, size: Rect):TextureRegion =
  newTextureRegion(texture,region,size,point(0,0),false)

template newTextureRegion*(texture: TexturePtr, x,y,w,h: cint): TextureRegion =
  newTextureRegion(texture,rect(x,y,w,h),rect(x,y,w,h))

template newTextureRegion*(texture: TexturePtr): TextureRegion =
  newTextureRegion(texture,rect(texture.x,texture.y,texture.w,texture.h),rect(texture.x,texture.y,texture.w,texture.h))

proc render*(renderer: RendererPtr, textureRegion: TextureRegion, x,y: cint, rotation:float = 0, scaleX, scaleY:float = 1, alpha: uint8 = 255) =
  var
    scaleXmod = scaleX
    scaleYmod = scaleY
    offsetX = textureRegion.offset.x
    offsetY = textureRegion.offset.y
  if scaleX<0:
    scaleXmod *= -1
    if not textureRegion.rotated:
      offsetX = textureRegion.size.x-textureRegion.region.w-textureRegion.offset.x
    else:
      offsetY = textureRegion.size.y-textureRegion.region.h-textureRegion.offset.y
  if scaleY<0:
    scaleYmod *= -1
    if textureRegion.rotated:
      offsetX = textureRegion.size.x-textureRegion.region.w-textureRegion.offset.x
    else:
      offsetY = textureRegion.size.y-textureRegion.region.h-textureRegion.offset.y
  var
    sX = scaleXmod
    sY = scaleYmod
  if textureRegion.rotated:
    let s = scaleXmod
    sX = scaleYmod
    sY = s
  var
    src = rect(textureRegion.region.x,textureRegion.region.y,textureRegion.region.w,textureRegion.region.h)
    c = point(
      ((textureRegion.size.x/2)-offsetX.float)*sX,
      ((textureRegion.size.y/2)-offsetY.float)*sY
    )
    r = (if textureRegion.rotated: c.x-c.y else: 0)
    ox = (if textureRegion.rotated: offsetY else: offsetX)
    oy = (if textureRegion.rotated: offsetX else: offsetY)
    dst = rect(
      ((x-r).float+ox.float*scaleXmod).cint,
      ((y+r).float+oy.float*scaleYmod).cint,
      (textureRegion.region.w.float*sX).cint,
      (textureRegion.region.h.float*sY).cint)

  textureRegion.texture.setTextureAlphaMod(alpha)
  renderer.copyEx(textureRegion.texture,
    src,
    dst,
    angle = (if textureRegion.rotated: 90 else: 0) + rotation,
    center = c.addr,
    flip = (if scaleX<0: (if textureRegion.rotated: SDL_FLIP_VERTICAL else: SDL_FLIP_HORIZONTAL) else: SDL_FLIP_NONE) or (if scaleY<0: (if textureRegion.rotated: SDL_FLIP_HORIZONTAL else: SDL_FLIP_VERTICAL) else: SDL_FLIP_NONE))
  textureRegion.texture.setTextureAlphaMod(255)

template render*(renderer: RendererPtr, textureRegion: TextureRegion, pos: Point, rotation:float = 0, scaleX, scaleY: float = 1, alpha:uint8 = 255) =
  renderer.render(textureRegion, pos.x.cint, pos.y.cint, rotation, scaleX, scaleY,alpha)
