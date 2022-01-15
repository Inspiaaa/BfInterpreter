
type SeqTape* = seq[uint8]

proc init*(self: var SeqTape) =
    self.add(0'u8)

template extendIfNecessary*(self: SeqTape, targetPos: int) =
    while len(self) <= targetPos:
            self.add(0)

template safeAccess*(self: SeqTape, targetPos: int): untyped =
    self.extendIfNecessary(targetPos)
    self[targetPos]


type ArrayTape* = array[30000, uint8]

proc init*(self: var ArrayTape) =
    discard

template extendIfNecessary*(self: ArrayTape, targetPos: int) =
    discard

template safeAccess*(self: ArrayTape, targetPos: int): untyped =
    self[targetPos]


type UncheckedArrayTape* = object
    data*: ptr UncheckedArray[uint8]

proc init*(self: var UncheckedArrayTape, size: int = 30000) =
    self.data = cast[ptr UncheckedArray[uint8]](alloc0(size))

proc `=destroy`*(self: var UncheckedArrayTape) =
    dealloc(self.data)

template extendIfNecessary*(self: UncheckedArrayTape, targetPos: int) =
    discard

template safeAccess*(self: UncheckedArrayTape, targetPos: int): untyped =
    self.data[targetPos]

template `[]=`*(self: UncheckedArrayTape, index: int, value: uint8): untyped =
    self.data[index] = value

template `[]`*(self: UncheckedArrayTape, index: int): untyped =
    self.data[index]
