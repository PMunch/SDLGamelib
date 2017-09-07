import json
import textureregion
import sdl2
import sdl2.image

type
  TileSet* = ref object
    tiles*: seq[TextureRegion]

proc initTileset*(): TileSet =
  new result
  result.tiles = @[]

proc loadIntoTileset*(renderer: RendererPtr, tileset: TileSet, data: JsonNode, offset = 0) =
  assert(data["type"].str == "tileset")
  let texture = renderer.loadTexture(data["image"].str)
  if tileset.tiles.len < offset + data["tilecount"].num:
    tileset.tiles.setLen(offset + data["tilecount"].num)
  let
    margin = data["margin"].num.cint
    spacing = data["spacing"].num.cint
    columns = data["columns"].num.cint
    tilewidth = data["tilewidth"].num.cint
    tileheight = data["tileheight"].num.cint
  for tile in 0..<data["tilecount"].num:
    let
      x = (tile mod columns).cint
      y = (tile div columns).cint
      textureregion = texture.newTextureRegion(
        margin + x*spacing + x*tilewidth,
        margin + y*spacing + y*tileheight,
        tilewidth,
        tileheight
      )
    tileset.tiles[(offset+tile).cint] = textureregion

