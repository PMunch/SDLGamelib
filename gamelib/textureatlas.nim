################################################################################
# The TextureAtlas implemented here supports all functions of the LibGDX
# texture atlas with the exception of MipMap levels and OpenGL texture filter.
# It creates lookup tables for texture regions, animations (of the AnimationTR
# type), and NinePatch images for quick access of the loaded regions. Texture
# atlases are used to minimize the overhead of writing textures into graphics
# memory separately and instead copies one large texture and then blits out
# copies of the regions in the texture.
################################################################################

import textureregion
import animation
import ninepatch
import tables
import sdl2
import sdl2.image
import strutils
import files
import streams

type
  TextureAtlas* = ref object
    regions: Table[string,TextureRegion]
    animations: Table[string,Animation[TextureRegion]]
    ninepatches: Table[string,NinePatch]

  #State = enum space, fname, size, format, filter, repeat, texName, texRot, texPos, texSize, texOrig, texOffset, texIndex

const field = (
  atlasSize: "size",
  colourFormat: "format",
  textureFilter: "filter",
  repeat: "repeat",
  texRotated: "  rotate",
  texPosition: "  xy",
  texAtlasSize: "  size",
  texOriginalSize: "  orig",
  texOffset: "  offset",
  texIndex: "  index",
  nineSplit: "  split",
  ninePad: "  pad")

proc getTextureCount*(atlas: TextureAtlas): int =
  return atlas.regions.len

proc getAnimationCount*(atlas: TextureAtlas): int =
  return atlas.animations.len

proc getTextureRegion*(atlas: TextureAtlas, name: string): TextureRegion =
  return atlas.regions[name]

proc getAnimation*(atlas: TextureAtlas, name: string): Animation[TextureRegion] =
  return atlas.animations[name]

proc getNinePatch*(atlas: TextureAtlas, name: string): NinePatch =
  return atlas.ninepatches[name]

proc getValue(line:string, field:string): string =
  return line[2+field.len .. line.high]

proc addCurrent(atlas:TextureAtlas, texture:TexturePtr, ninePatch: bool, curName:string,  curRegion:var Rect, curRotation:bool, curSize: var Rect, curOffset: var Point, curIndex: cint, curNineSplit: Lengths, curNinePad: Lengths) =


  curOffset.y = curSize.y-curRegion.h-curOffset.y

  if curRotation:
    let tmpH = curRegion.h
    curRegion.h = curRegion.w
    curRegion.w = tmpH
    let tmpS = curSize.y
    curSize.y = curSize.x
    curSize.x = tmpS
    let tmpX = curOffset.x
    curOffset.x = curOffset.y
    curOffset.y = tmpX
    curOffset.y = curSize.y-curRegion.h-curOffset.y


  if curIndex == -1 and ninePatch == false:
    atlas.regions[curName]= newTextureRegion(texture,curRegion,curSize,curOffset,curRotation)
  elif ninePatch == false:
    if atlas.animations.hasKey(curName):
      atlas.animations[curName].frames.insert(newTextureRegion(texture,curRegion,curSize,curOffset,curRotation),min(curIndex,atlas.animations[curName].frames.len))
    else:
      atlas.animations[curName]=newAnimation(@[newTextureRegion(texture,curRegion,curSize,curOffset,curRotation)])
  else:
    atlas.ninepatches[curName]=newNinePatch(texture,curRegion,curSize,curOffset,curRotation,curNineSplit,curNinePad)

proc loadAtlas*(renderer: RendererPtr, atlasFileName: string): TextureAtlas =
  new result
  result.regions = initTable[string,TextureRegion]()
  result.animations = initTable[string,Animation[TextureRegion]]()
  result.ninepatches = initTable[string,NinePatch]()
  var
    lineCount = 0
    texture: TexturePtr
    rwStream = newStreamWithRWops(rwFromFile(atlasFileName, "rb"))
    ninePatch: bool = false
    curName:string
    curRegion:Rect
    curRotation:bool
    curSize: Rect
    curOffset: Point
    curIndex: cint
    curNineSplit: Lengths
    curNinePad: Lengths
  defer: rwStream.close()
  for line in rwStream.lines:
    if lineCount == 0:
      discard
    elif lineCount == 1:
      echo "Loading texture ",line
      texture = renderer.loadTexture(line)
    else:
      # If the line starts with two spaces it's part of a texture
      if not line.startsWith("  "):
        if line == "":
          addCurrent(result,texture,ninePatch,curName,curRegion,curRotation,curSize,curOffset,curIndex,curNineSplit,curNinePad)
          ninePatch = false
          lineCount = 1
          continue
        case line.split(":")[0]:
          of field.atlasSize:
            # Don't need this field for anything in particular
            discard
          of field.colourFormat:
            # Colour format should be automatically detected by SDL
            discard
          of field.textureFilter:
            # OpenGL texture filter and MipMap options
            discard
          of field.repeat:
            # According to the libGDX sources this options appears to do nothing
            discard
          else:
            addCurrent(result,texture,ninePatch,curName,curRegion,curRotation,curSize,curOffset,curIndex,curNineSplit,curNinePad)
            ninePatch = false
            curName = line
      else:
        case line.split(":")[0]:
          of field.texRotated:
            if getValue(line,field.texRotated) == "true":
              curRotation = true
            else:
              curRotation = false
          of field.texPosition:
            let
              position = getValue(line,field.texPosition)
              cords = position.split(", ")
              x = cords[0].parseInt.cint
              y = cords[1].parseInt.cint
            curRegion.x = x
            curRegion.y = y
          of field.texAtlasSize:
            let
              atlasSize = getValue(line,field.texAtlasSize)
              wh = atlasSize.split(", ")
              w = wh[0].parseInt.cint
              h = wh[1].parseInt.cint
            curRegion.w = w
            curRegion.h = h
          of field.texOriginalSize:
            let
              origSize = getValue(line,field.texOriginalSize)
              wh = origSize.split(", ")
              w = wh[0].parseInt.cint
              h = wh[1].parseInt.cint
            curSize.x = w
            curSize.y = h
          of field.texOffset:
            let
              offset = getValue(line,field.texOffset)
              xy = offset.split(", ")
              x = xy[0].parseInt.cint
              y = xy[1].parseInt.cint
            curOffset.x = x
            curOffset.y = y
          of field.texIndex:
            curIndex = getValue(line,field.texIndex).parseInt.cint
          of field.nineSplit:
            let
              values = getValue(line,field.nineSplit)
              splits = values.split(", ")
            curNineSplit = lengths(splits[0].parseInt.cint,splits[1].parseInt.cint,splits[2].parseInt.cint,splits[3].parseInt.cint)
            ninePatch = true
          of field.ninePad:
            let
              values = getValue(line,field.ninePad)
              pads = values.split(", ")
            curNinePad = lengths(pads[0].parseInt.cint,pads[1].parseInt.cint,pads[2].parseInt.cint,pads[3].parseInt.cint)
            ninePatch = true
          else:
            discard
    lineCount+=1

  addCurrent(result,texture,ninePatch,curName,curRegion,curRotation,curSize,curOffset,curIndex,curNineSplit,curNinePad)
