
# Intermediate representation of the BF code

type
    InstrKind* = enum
        # Default: Used to avoid errors when doing pattern matching at the end of the instruction string.
        opEnd,

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

    TPos* = int32
    TCell* = uint8

    # Represents one instruction that can be executed by the interpreter.
    # Every instruction has a type (-> opcode), and can optionally store one cell value (uint8)
    # and one tape position (int32).
    # Currently sizeof(Instr) = 8 bytes
    Instr* = object
        # The performance of the interpreter is quite sensitive to the order of these fields.
        pos*: TPos
        kind*: InstrKind
        value*: TCell

# echo sizeof(Instr)

# Aliases for the common fields of Instr to enhance readability.
template offset*(instr: Instr): untyped = instr.pos
template scanStep*(instr: Instr): untyped = instr.pos
template factor*(instr: Instr): untyped = instr.value


proc `==`*(a: Instr, kind: InstrKind): bool =
    a.kind == kind

proc `!=`*(a: Instr, kind: InstrKind): bool =
    a.kind != kind
