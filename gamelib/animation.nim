## An animation is a general purpose container that has a collection of elements
## which is cycled as time passes. To get the current frame call the frame()
## procedure.
##
## A special class, AnimationTR, is created as an alias for an animation of
## TextureRegions. As AnimationTR object can either be created from a single
## texture, texture region or a sequence of texture regions. In the two first
## cases the texture or texture region will be split into a sequence of texture
## regions based on it's frames count for internal use (note that the texture is
## not modified).
##
## Currently two AnimationTypes are supported: cycle and pingpong. Cycle wraps
## around when it comes to the end while pingpong reverses the animation and
## runs it back backwards.
##
## The tick function takes the number of seconds since it was called to ensure
## that animations are always running at the same speed.
##
## Rendering is supported for the AnimationTR type and uses the same options as
## a texture region.


import sdl2
import textureregion

type
  AnimationType* {.pure.} = ## Enum type to select what the animation should do
    ## when it comes to it's end. Pingpong means that it reverts direction and
    ## cycle means that it starts over.
    enum pingpong, cycle

  Animation*[T] = ref object
    ## Animation type to pass into these procedures
    frames*: seq[T] ## The sequence of frames
    frameIndex*: int ## The current frame, change to jump to a specific frame
    timeSinceLastFrame: float
    longestFrameTime:float
    animationType: AnimationType
    speed: int

  AnimationTR* = ## Convenience type for an animation of TextureRegions
    Animation[TextureRegion]

proc setFps*(animation: Animation, fps:float) =
  ## Set the FPS of the given animation. Can be negative to run the animation in
  ## reverse, or zero to stop the animation.
  if fps>0:
    animation.longestFrameTime = 1/fps
    animation.speed = 1
  elif fps<0:
    animation.longestFrameTime = -1/fps
    animation.speed = -1
  else:
    animation.speed = 0

proc setAnimationType*(animation: Animation, animationType: AnimationType) =
  ## Set the animation type.
  animation.animationType = animationType

proc tick*(animation: Animation, time: float) =
  ## Move the animation forwards given the time since the last tick.
  if animation.speed != 0:
    animation.timeSinceLastFrame += time
    while animation.timeSinceLastFrame > animation.longestFrameTime:
      animation.frameIndex += animation.speed
      if animation.frameIndex > animation.frames.high or animation.frameIndex <= 0:
        case animation.animationType:
          of AnimationType.cycle:
            animation.frameIndex = 0
          of AnimationType.pingpong:
            animation.speed = if animation.speed == 1: -1 else: 1
            animation.frameIndex = animation.frameIndex.clamp(0,animation.frames.high)
      animation.timeSinceLastFrame -= animation.longestFrameTime

proc newAnimation*[T](frames: seq[T], fps: float = 12, animationType: AnimationType = AnimationType.cycle): Animation[T] =
  ## Create a new animation from a set of frames and optionally an FPS and
  ## AnimationType.
  new result
  result.frames = frames
  result.animationType = animationType
  result.speed = 1
  result.setFps(fps)

proc frame*[T](animation: Animation[T]): T=
  ## Gets the current frame for an animation
  animation.frames[animation.frameIndex]


# SDL specific stuff:

proc render*(renderer: RendererPtr, animation: AnimationTR, x,y: cint, rotation: float = 0, scaleX, scaleY: float = 1, alpha:uint8 = 255) =
  ## Convenience procedure for rendering the current frame of an animation of
  ## TextureRegions.
  renderer.render(animation.frame,x,y,rotation,scaleX,scaleY,alpha)

template render*(renderer: RendererPtr, animation: AnimationTR, pos: Point,  rotation:float = 0, scaleX, scaleY: float = 1, alpha:uint8 = 255) =
  ## Convenience procedure for rendering the current frame of an animation of
  ## TextureRegions.
  render(renderer,animation,pos.x,pos.y,rotation,scaleX,scaleY,alpha)

proc newAnimation*(textureRegion: TextureRegion, frames: int, fps: float = 12, animationType: AnimationType = AnimationType.cycle): AnimationTR =
  ## Convenience procedure to create an Animation from a texture region and the
  ## number of frames in the region (horizontal split only for now).
  new result
  result.animationType = animationType
  result.speed = 1
  result.frames = @[]
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
      result.frames.add(newTextureRegion(textureRegion.texture, region, size, textureRegion.offset, textureRegion.rotated))
    elif i<frames-1:
      var
        region = result.frames[i-1].region
        offset = point(0,0)
      if textureRegion.rotated:
        region.y += size.y - (if i==1: textureRegion.offset.y else: 0)
        region.h = size.x
        offset.x = textureRegion.offset.x
      else:
        region.x += size.x - (if i==1: textureRegion.offset.x else: 0)
        region.w = size.y
        offset.y = textureRegion.offset.y
      result.frames.add(newTextureRegion(textureRegion.texture, region, size, offset, textureRegion.rotated))
    else:
      var
        region = result.frames[i-1].region
        offset = point(0,0)
      if textureRegion.rotated:
        region.y += size.y
        region.h -= textureRegion.offset.y
        offset.x = textureRegion.offset.x
      else:
        region.x += size.x
        region.w -= textureRegion.offset.x
        offset.y = textureRegion.offset.y
      result.frames.add(newTextureRegion(textureRegion.texture, region, size, offset, textureRegion.rotated))

  if textureRegion.rotated:
    let textureRegions = result.frames
    result.frames = newSeq[TextureRegion](textureRegions.len)
    for i in 0..textureRegions.high:
      result.frames[i] = textureRegions[textureRegions.high-i]

template newAnimation*(texture: TexturePtr, region: Rect, frames: int, fps: int, animationType: AnimationType): AnimationTR =
  ## Convenience template to create a new animation from a texture, a region and
  ## the number of frames in the region (horizontal split only for now).
  newAnimation(texture.newTextureRegion(region.x,region.y,region.w,region.h),frames,fps,animationType)
