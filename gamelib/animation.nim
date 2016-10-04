################################################################################
# An animation object can either be created from a single texture, texture
# region or a sequence of texture regions. In the two first cases the texture
# or texture region will be split into a sequence of texture regions based on
# it's frames count for internal use (note that the texture is not modified).
#
# Currently two AnimationTypes are supported cycle and pingpong. Cycle wraps
# around when it comes to the end while pingpong reverses the animation and
# runs it back backwards.
#
#The tick function takes the number of seconds since it was called to ensure
# that animations are always running at the same speed.
#
# Rendering supports the same options as a texture region
################################################################################

import sdl2
import textureregion

type
  AnimationType* {.pure.} = enum pingpong, cycle

  Animation* = ref object
    textureRegions*: seq[TextureRegion]
    frame*: int
    timeSinceLastFrame: float
    longestFrameTime:float
    animationType: AnimationType
    speed: int
    frameWidth, frameHeight: cint

template newAnimation*(texture: TexturePtr, region: Rect, frames: int, fps: int, animationType: AnimationType): Animation =
  newAnimation(texture.newTextureRegion(region),frames,fps,animationType)

proc setFps*(animation: Animation, fps:float) =
  if fps>0:
    animation.longestFrameTime = 1/fps
  elif fps<0:
    animation.longestFrameTime = -1/fps
    animation.speed = animation.speed * -1
  else:
    animation.speed = 0

proc setAnimationType*(animation: Animation, animationType: AnimationType) =
  animation.animationType = animationType

proc tick*(animation: Animation, time: float) =
  if animation.speed != 0:
    animation.timeSinceLastFrame += time
    while animation.timeSinceLastFrame > animation.longestFrameTime:
      animation.frame += animation.speed
      if animation.frame >= animation.textureRegions.high or animation.frame <= 0:
        case animation.animationType:
          of AnimationType.cycle:
            animation.frame = 0
          of AnimationType.pingpong:
            animation.speed = if animation.speed == 1: -1 else: 1
            animation.frame = animation.frame.clamp(0,animation.textureRegions.high)
      animation.timeSinceLastFrame -= animation.longestFrameTime

template render*(renderer: RendererPtr, animation: Animation, pos: Point,  rotation:float = 0, scaleX, scaleY: float = 1, alpha:uint8 = 255) =
  render(renderer,animation,pos.x,pos.y,rotation,scaleX,scaleY,alpha)

proc render*(renderer: RendererPtr, animation: Animation, x,y: cint, rotation: float = 0, scaleX, scaleY: float = 1, alpha:uint8 = 255) =
  let activeFrame = animation.textureRegions[animation.frame]
  renderer.render(activeFrame,x,y,rotation,scaleX,scaleY,alpha)

proc newAnimation*(textureRegions: seq[TextureRegion], fps: float = 12, animationType: AnimationType = AnimationType.cycle): Animation =
  new result
  result.textureRegions = textureRegions
  result.animationType = animationType
  result.speed = 1
  result.setFps(fps)

  result.frameHeight = textureRegions[0].size.h
  result.frameWidth = textureRegions[0].size.w

proc newAnimation*(textureRegion: TextureRegion, frames: int, fps: float = 12, animationType: AnimationType = AnimationType.cycle): Animation =
  new result
  result.animationType = animationType
  result.speed = 1
  result.textureRegions = @[]
  result.setFps(fps)

  var size = textureRegion.size
  if not textureRegion.rotated:
    size.x = (size.x / frames).cint
  else:
    size.y = (size.y / frames).cint

  for i in 0..<frames:
    if i==0:
      var region = textureRegion.region
      region.w = size.x - textureRegion.offset.x
      region.h = size.y - textureRegion.offset.y
      result.textureRegions.add(newTextureRegion(textureRegion.texture, region, size, textureRegion.offset, textureRegion.rotated))
    elif i<frames-1:
      var
        region = result.textureRegions[i-1].region
        offset = point(0,0)
      if textureRegion.rotated:
        region.y += size.y - (if i==1: textureRegion.offset.y else: 0)
        region.h = size.x
        offset.x = textureRegion.offset.x
      else:
        region.x += size.x - (if i==1: textureRegion.offset.x else: 0)
        region.w = size.y
        offset.y = textureRegion.offset.y
      result.textureRegions.add(newTextureRegion(textureRegion.texture, region, size, offset, textureRegion.rotated))
    else:
      var
        region = result.textureRegions[i-1].region
        offset = point(0,0)
      if textureRegion.rotated:
        region.y += size.y
        region.h -= textureRegion.offset.y
        offset.x = textureRegion.offset.x
      else:
        region.x += size.x
        region.w -= textureRegion.offset.x
        offset.y = textureRegion.offset.y
      result.textureRegions.add(newTextureRegion(textureRegion.texture, region, size, offset, textureRegion.rotated))

  if textureRegion.rotated:
    let textureRegions = result.textureRegions
    result.textureRegions = newSeq[TextureRegion](textureRegions.len)
    for i in 0..textureRegions.high:
      result.textureRegions[i] = textureRegions[textureRegions.high-i]
