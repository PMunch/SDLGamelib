################################################################################
# Helper functions for rendering of SDL2 truetype fonts. In order for SDL2 to
# render fonts they have to be converted to a texture first. The functions in
# here help with caching this texture and makes sure it's only regenerated
# whenever the result of an update will be functionally different from the
# current texture.
#
# Note that the blend modes carries some extra special meaning.
# - Setting the blend mode to shade requires the setBackground procedure to be
# called before a texture is generated.
# - For text wrapping the blend mode has to be set to blended. This is a
# limitaton in SDL2 (there are no wrapped render functions for the other
# modes). A future workaround for this might be implemented.
################################################################################

import sdl2
import sdl2.ttf

type
  TextBlendMode* {.pure.} = enum solid, shaded, blended
  Text* = ref object
    lastString: cstring
    texture: TexturePtr
    color: Color
    background: Color
    region: Rect
    font: FontPtr
    renderer: RendererPtr
    blendMode: TextBlendMode
    maxWidth: uint32

proc render* (renderer: RendererPtr, text:Text, x,y:cint, rotation: float = 0, scaleX, scaleY: float = 1, alpha: uint8 = 255) =
  var dest = rect(x, y, (text.region.w.float*scaleX).cint, (text.region.h.float*scaleY).cint)

  text.texture.setTextureAlphaMod(alpha)
  renderer.copyEx(text.texture, text.region, dest, angle = rotation, center = nil,
                  flip = SDL_FLIP_NONE)

proc createTexture(text:Text) =
  let surface =
    if text.blendMode == TextBlendMode.blended:
      text.font.renderUtf8BlendedWrapped(text.lastString, text.color,text.maxWidth)
    elif text.blendMode == TextBlendMode.solid:
      text.font.renderUtf8Solid(text.lastString, text.color)
    elif text.blendMode == TextBlendMode.shaded:
      text.font.renderUtf8Shaded(text.lastString, text.color, text.background)
    else:
      nil
  text.region = rect(0,0,surface.w,surface.h)

  discard surface.setSurfaceAlphaMod(text.color.a)
  if text.texture != nil:
    text.texture.destroy()
  text.texture = text.renderer.createTextureFromSurface(surface)
  surface.freeSurface()

proc setText*(text:Text, str:string) =
  if text.lastString != str:
    text.lastString = str
    text.createTexture

proc setColor*(text:Text, color:Color) =
  if text.color != color:
    text.color = color
    text.createTexture

proc setFont*(text:Text, font: FontPtr) =
  if text.font != font:
    text.font = font
    text.createTexture

proc setMaxWidth*(text:Text, maxWidth:uint32) =
  if text.maxWidth != maxWidth:
    text.maxWidth = maxWidth
    text.createTexture

proc setBackground*(text:Text, background: Color) =
  if text.background != background:
    text.background = background
    text.createTexture

proc newText* (renderer: RendererPtr, font: FontPtr, text: string, color:Color = color(255,255,255,0), blendMode: TextBlendMode = TextBlendMode.solid, maxWidth: uint32 = uint32.high): Text =
  new result
  result.lastString = text
  result.font = font
  result.renderer = renderer
  result.color = color
  result.maxWidth = maxWidth
  result.blendMode = blendMode
  if result.blendMode != TextBlendMode.shaded:
    result.createTexture
