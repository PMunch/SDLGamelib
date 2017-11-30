## Helper functions for rendering of SDL2 truetype fonts. In order for SDL2 to
## render fonts they have to be converted to a texture first. The functions in
## here help with caching this texture and makes sure it's only regenerated
## whenever the result of an update will be functionally different from the
## current texture.
##
## Note that the blend modes carries some extra special meaning.
## - Setting the blend mode to shade requires the setBackground procedure to be
## called before a texture is generated.
## - For text wrapping the blend mode has to be set to blended. This is a
## limitaton in SDL2 (there are no wrapped render functions for the other
## modes). A future workaround for this might be implemented.

import sdl2
import sdl2.ttf

type
  TextBlendMode* {.pure.} = ## The SDL blend mode to use for the text
    enum solid, shaded, blended
  Text* = ref object
    ## Text object to pass into these procedures
    lastString*: cstring
    case hasTexture*: bool
    of true:
      texture*: TexturePtr
    of false:
      surface*: SurfacePtr
    color: Color
    background: Color
    region: Rect
    font: FontPtr
    renderer: RendererPtr
    blendMode: TextBlendMode
    maxWidth: uint32

proc render* (renderer: RendererPtr, text:Text, x,y:cint, rotation: float = 0, scaleX, scaleY: float = 1, alpha: uint8 = 255) =
  ## Render the cached texture at the given position
  var dest = rect(x, y, (text.region.w.float*scaleX).cint, (text.region.h.float*scaleY).cint)

  text.texture.setTextureAlphaMod(alpha)
  renderer.copyEx(text.texture, text.region, dest, angle = rotation, center = nil,
                  flip = SDL_FLIP_NONE)

proc createSurface(text: Text): SurfacePtr =
  result =
    if text.blendMode == TextBlendMode.blended:
      text.font.renderUtf8BlendedWrapped(text.lastString, text.color,text.maxWidth)
    elif text.blendMode == TextBlendMode.solid:
      text.font.renderUtf8Solid(text.lastString, text.color)
    elif text.blendMode == TextBlendMode.shaded:
      text.font.renderUtf8Shaded(text.lastString, text.color, text.background)
    else:
      nil
  if result == nil:
    echo "'" & $(text.lastString) & "'"
  text.region = rect(0,0,result.w,result.h)

  discard result.setSurfaceAlphaMod(text.color.a)

proc refreshData(text:Text) =
  let surface = text.createSurface()
  if text.hasTexture:
    if text.texture != nil:
      text.texture.destroy()
    text.texture = text.renderer.createTextureFromSurface(surface)
    surface.freeSurface()
  else:
    if text.surface != nil:
      text.surface.freeSurface()
    text.surface = surface

proc setText*(text:Text, str:string) =
  ## Set the text of the text object and regenerate the cached texture if the
  ## string is different.
  if text.lastString != str:
    text.lastString = str
    text.refreshData

proc setColor*(text:Text, color:Color) =
  ## Set the color of the text and regenerate the cached texture if it's
  ## different.
  if text.color != color:
    text.color = color
    text.refreshData

proc setFont*(text:Text, font: FontPtr) =
  ## Set the font of the text and regenerate the cached texture if it's
  ## different.
  if text.font != font:
    text.font = font
    text.refreshData

proc setMaxWidth*(text:Text, maxWidth:uint32) =
  ## Sets the max width of the text. For text wrapping the blend mode has to be
  ## set to blended. This is a limitaton in SDL2.
  if text.maxWidth != maxWidth:
    text.maxWidth = maxWidth
    text.refreshData

proc setBackground*(text:Text, background: Color) =
  ## Sets the background color of the text for the shaded blend mode.
  if text.background != background:
    text.background = background
    text.refreshData

proc newText* (renderer: RendererPtr, font: FontPtr, text: string, color:Color = color(255,255,255,0), blendMode: TextBlendMode = TextBlendMode.solid, maxWidth: uint32 = uint32.high, hasTexture: bool = true): Text =
  ## Creates a new text object.
  new result
  result.lastString = text
  result.font = font
  result.renderer = renderer
  result.color = color
  result.maxWidth = maxWidth
  result.blendMode = blendMode
  result.hasTexture = hasTexture
  if result.blendMode != TextBlendMode.shaded:
    result.refreshData
