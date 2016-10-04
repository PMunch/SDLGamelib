################################################################################
# The content of this file is borrowed directly from the nimx project:
# https://github.com/yglukhov/nimx/blob/master/nimx/resource.nim
# Sole exception is the lines iterator
# This is used to make the code interoperable across all SDL2 supported devices
################################################################################

import sdl2
import streams

type
  RWOpsStream = ref RWOpsStreamObj
  RWOpsStreamObj = object of StreamObj
    ops: RWopsPtr

proc rwClose(s: Stream) {.nimcall.} =
    let ops = RWOpsStream(s).ops
    if ops != nil:
        discard ops.close(ops)
        RWOpsStream(s).ops = nil
proc rwAtEnd(s: Stream): bool {.nimcall.} =
    let ops = s.RWOpsStream.ops
    result = ops.size(ops) == ops.seek(ops, 0, 1)
proc rwSetPosition(s: Stream, pos: int) {.nimcall.} =
    let ops = s.RWOpsStream.ops
    discard ops.seek(ops, pos.int64, 0)
proc rwGetPosition(s: Stream): int {.nimcall.} =
    let ops = s.RWOpsStream.ops
    result = ops.seek(ops, 0, 1).int

proc rwReadData(s: Stream, buffer: pointer, bufLen: int): int {.nimcall.} =
    let ops = s.RWOpsStream.ops
    let res = ops.read(ops, buffer, 1, bufLen.csize)
    result = res

proc rwWriteData(s: Stream, buffer: pointer, bufLen: int) {.nimcall.} =
    let ops = s.RWOpsStream.ops
    if ops.write(ops, buffer, 1, bufLen) != bufLen:
        raise newException(IOError, "cannot write to stream")

proc newStreamWithRWops*(ops: RWopsPtr): RWOpsStream =
  if ops.isNil: return
  result.new()
  result.ops = ops
  result.closeImpl = cast[type(result.closeImpl)](rwClose)
  result.atEndImpl = cast[type(result.atEndImpl)](rwAtEnd)
  result.setPositionImpl = cast[type(result.setPositionImpl)](rwSetPosition)
  result.getPositionImpl = cast[type(result.getPositionImpl)](rwGetPosition)
  result.readDataImpl = cast[type(result.readDataImpl)](rwReadData)
  result.writeDataImpl = cast[type(result.writeDataImpl)](rwWriteData)

iterator lines*(s: Stream): string =
  var str = ""
  while s.readLine(str):
    yield str
