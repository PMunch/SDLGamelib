import json
import tileset
import sdl2
import sdl2/ttf
import tables
import text
import strutils

type
  ObjectKind* = enum
    TileObject, TextObject

  MapObject* = object
    width*, height*: int
    x*, y*: int
    visible*: bool
    rotation*: float
    case kind*: ObjectKind
    of TileObject:
      tile*: int
    of TextObject:
      text*: Text

  LayerKind* = enum
    TileLayer, ObjectGroup

  MapLayer* = object
    opacity*: int
    name*: string
    visible*: bool
    x*: int
    y*: int
    case kind*: LayerKind
    of TileLayer:
      tiles*: seq[seq[int]]
    of ObjectGroup:
      objects*: seq[MapObject]

  TileMap* = ref object
    tilewidth*: int
    tileheight*: int
    layers*: seq[MapLayer]
    tileset*: TileSet

proc loadTilemap*(renderer: RendererPtr, data: JsonNode, fontFamilies: TableRef[string, FontPtr] = nil): TileMap =
  new result
  assert(data["type"].str == "map")
  assert(data["orientation"].str == "orthogonal")
  result.tilewidth = data["tilewidth"].num.int
  result.tileheight = data["tileheight"].num.int
  result.tileset = initTileset()
  result.layers = @[]
  for tileset in data["tilesets"]:
    if tileset.hasKey("source"):
      renderer.loadIntoTileset(result.tileset, parseFile(tileset["source"].str), tileset["firstgid"].num.int)
    else:
      renderer.loadIntoTileset(result.tileset, tileset, tileset["firstgid"].num.int)
  for layer in data["layers"]:
    var curLayer: MapLayer
    case layer["type"].str:
    of "tilelayer":
      curLayer = MapLayer(kind: TileLayer)
      curLayer.tiles = newSeq[seq[int]](layer["width"].num)
      var ti = 0
      for x in 0..<layer["width"].num.int:
        curLayer.tiles[x] = newSeq[int](layer["height"].num)
        for y in 0..<curLayer.tiles[x].len:
          curLayer.tiles[x][y] = layer["data"][ti].num.int
          ti += 1
    of "objectgroup":
      curLayer = MapLayer(kind: ObjectGroup)
      curLayer.objects = @[]#newSeq[MapObject](layer["objects"].elems.len)
      for i in 0..<layer["objects"].elems.len:
        var mapObject: MapObject
        let objData = layer["objects"][i]
        if layer["objects"][i].hasKey("gid"):
          mapObject = MapObject(kind: TileObject)
          mapObject.tile = objData["gid"].num.int
        elif objData.hasKey("text"):
          if fontFamilies == nil:
            when defined(debug):
              echo("Cannot load text objects from tilemap when not passed a table of fonts")
            continue
          mapObject = MapObject(kind: TextObject)
          let
            textObj = objData["text"]
            size =
              if textObj.hasKey("pixelsize"):
                textObj["pixelsize"].num
              else:
                16
            font =
              if textObj.hasKey("fontfamily"):
                fontFamilies[textObj["fontfamily"].str & "/" & $size]
              else:
                fontFamilies["Arial/" & $size]
            colorStr =
              if textObj.hasKey("color"):
                textObj["color"].str
              else:
                "#000000"
            color = color(colorStr[1..2].parseHexInt,colorStr[3..4].parseHexInt,colorStr[5..6].parseHexInt,0)
          mapObject.text = renderer.newText(font, objData["text"]["text"].str, color = color)
        mapObject.x = if objData["x"].kind == JInt: objData["x"].num.int else: objData["x"].fnum.int
        mapObject.y = if objData["y"].kind == JInt: objData["y"].num.int else: objData["y"].fnum.int
        mapObject.width = if objData["width"].kind == JInt: objData["width"].num.int else: objData["width"].fnum.int
        mapObject.height = if objData["height"].kind == JInt: objData["height"].num.int else: objData["height"].fnum.int
        mapObject.visible = objData["visible"].bval
        mapObject.rotation = objData["rotation"].num.float
        curLayer.objects.add mapObject
    curLayer.opacity = layer["opacity"].num.int
    curLayer.name = layer["name"].str
    curLayer.visible = layer["visible"].bval
    curLayer.x = layer["x"].num.int
    curLayer.y = layer["y"].num.int
    result.layers.add(curLayer)

proc loadTilemap*(renderer: RendererPtr, mapFileName: string, fontFamilies: TableRef[string, FontPtr] = nil): TileMap =
  loadTilemap(renderer, parseFile(mapFileName), fontFamilies) 
