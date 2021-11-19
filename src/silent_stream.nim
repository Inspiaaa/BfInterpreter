
import std/streams


proc discardWrite(s: Stream, buffer: pointer, bufLen: int) =
    discard


proc newSilentStream*(): owned Stream =
    new(result)
    result.writeDataImpl = discardWrite