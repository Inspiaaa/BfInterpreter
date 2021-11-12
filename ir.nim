
# Intermediate representation of the BrainFuck code

type
    InstrKind* = enum
        # Default: Used to avoid errors when doing pattern matching at the end of the instruction string
        opNone
        opAdd,
        opSub,
        opMove,
        opLoopStart,
        opLoopEnd,
        opRead,
        opWrite,
        opClear,
        opScan,  # Moves to the next empty (0) cell to the right / left by jumping certain increments
        opCopyAdd,  # Adds the current cell value to another cell
        opCopySub,  # Subtracts ...
        opSetupMul,  # Sets the multiplication factor
        opMulAdd,  # Adds the current cell times the value stored multiplication factor to another cell
        opMulSub

    Instr* = object
        case kind*: InstrKind
        of opAdd:
            add*: uint8
        of opSub:
            sub*: uint8
        of opMove:
            move*: int
        of opLoopStart:
            endPos*: int
        of opLoopEnd:
            startPos*: int
        of opRead, opWrite, opClear: discard
        of opScan:
            scanStep*: int
        of opCopyAdd:
            copyAddOffset*: int
        of opCopySub:
            copySubOffset*: int
        of opSetupMul:
            mul*: uint8
        of opMulAdd:
            mulAddOffset*: int
        of opMulSub:
            mulSubOffset*: int
        of opNone: discard



proc `==`*(a: Instr, kind: InstrKind): bool =
    a.kind == kind

proc `==`*(a: Instr, b: Instr): bool =
    if a.kind != b.kind:
        return false

    case a.kind
    of opAdd:
        return a.add == b.add
    of opSub:
        return a.sub == b.sub
    of opMove:
        return a.move == b.move
    of opLoopStart:
        return a.startPos == b.startPos
    of opLoopEnd:
        return a.endPos == b.endPos
    else:
        return true

proc `!=`*(a: Instr, kind: InstrKind): bool =
    a.kind != kind
