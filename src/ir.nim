
# Intermediate representation of the BF code

type
    InstrKind* = enum
        # Default: Used to avoid errors when doing pattern matching at the end of the instruction string.
        opNone,

        # Standard instructions

        opAdd,   # + or +++ ...
        opSub,   # - or -- ...
        opMove,  # > or <

        opLoopStart,  # [
        opLoopEnd,    # ]

        opWrite,  # .
        opRead,   # ,

        # Advanced instructions

        opClear,  # [-]: Clears the current cell.
        opSet,    # [-]++ or [-]- ...: Sets the current cell to a certain value.

        # Moves to the next empty (0) cell to the right / left by jumping certain increments.
        opScan,  # [>] or [<] or [>>>] or ...

        # Adds / subtracts the current cell value to (/from) another cell.
        opCopyAdd,  # [->+<] or [->>+++<<] ...
        opCopySub,  # [->-<] or [->>---<<] ...

        # Adds / subtracts the current cell times the value stored multiplication factor to another cell.
        opMulAdd,  # [->+++<] ...
        opMulSub,  # [->---<] ...

        # Adds / subtracts a certain amount to (/from) a different cell.
        opAddAtOffset,  # >>>+ or >>+++ ...
        opSubAtOffset,  # >>>- or >>--- ...

    ValueWithOffset* = ref object
        cell*: uint8
        tape*: int

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
        of opSet:
            setValue*: uint8

        of opScan:
            scanStep*: int

        of opCopyAdd:
            copyAddOffset*: int
        of opCopySub:
            copySubOffset*: int

        of opMulAdd:
            mulAddOffset*: ValueWithOffset
        of opMulSub:
            mulSubOffset*: ValueWithOffset

        of opAddAtOffset:
            addAtOffset*: ValueWithOffset
        of opSubAtOffset:
            subAtOffset*: ValueWithOffset

        of opNone:
            discard


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
    of opScan:
        return a.scanStep == b.scanStep
    of opCopyAdd:
        return a.copyAddOffset == b.copyAddOffset
    of opCopySub:
        return a.copySubOffset == b.copySubOffset
    of opMulAdd:
        return a.mulAddOffset[] == b.mulAddOffset[]
    of opMulSub:
        return a.mulSubOffset[] == b.mulSubOffset[]
    of opAddAtOffset:
        return a.addAtOffset[] == b.addAtOffset[]
    of opSubAtOffset:
        return a.subAtOffset[] == b.subAtOffset[]
    of opSet:
        return a.setValue == b.setValue
    else:
        return true

proc `!=`*(a: Instr, kind: InstrKind): bool =
    a.kind != kind
