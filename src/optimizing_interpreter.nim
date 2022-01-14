
import std/streams
import ./ir
import ./optimization


type SeqTape {.borrow: `.`.} = distinct seq[uint8]

proc add(self: var SeqTape, value: uint8) {.borrow.}
proc len(self: SeqTape): int {.borrow.}

proc init(self: var SeqTape) =
    self.add(0'u8)

template extendIfNecessary(self: SeqTape, targetPos: int) =
    while len(self) <= targetPos:
            self.add(0)

template safeAccess(self: SeqTape, targetPos: int): untyped =
    self.extendIfNecessary(targetPos)
    self[targetPos]

template `[]=`(self: SeqTape, index: int, value: uint8): untyped =
    seq[uint8](self)[index] = value

template `[]`(self: SeqTape, index: int): untyped =
    seq[uint8](self)[index]


type ArrayTape = object
    data: array[30000, uint8]

proc init(self: var ArrayTape) =
    discard

template extendIfNecessary(self: ArrayTape, targetPos: int) =
    discard

template safeAccess(self: ArrayTape, targetPos: int): untyped =
    self[targetPos]

template `[]=`(self: ArrayTape, index: int, value: uint8): untyped =
    self.data[index] = value

template `[]`(self: ArrayTape, index: int): untyped =
    self.data[index]


type UncheckedArrayTape = object
    data: ptr UncheckedArray[uint8]

proc init(self: var UncheckedArrayTape) =
    self.data = cast[ptr UncheckedArray[uint8]](alloc0(30000))

proc `=destroy`(self: var UncheckedArrayTape) =
    dealloc(self.data)

template extendIfNecessary(self: UncheckedArrayTape, targetPos: int) =
    discard

template safeAccess(self: UncheckedArrayTape, targetPos: int): untyped =
    self.data[targetPos]

template `[]=`(self: UncheckedArrayTape, index: int, value: uint8): untyped =
    self.data[index] = value

template `[]`(self: UncheckedArrayTape, index: int): untyped =
    self.data[index]


proc sanitizeCode(code: string): string =
    ## Removes characters that are not instructions

    var sanitized: string = ""

    for c in code:
        case c
        of '+', '-', '<', '>', '[', ']', '.', ',':
            sanitized.add(c)
        else: discard

    return sanitized


proc parse*(code: string): seq[Instr] =
    ## Converts a string BF code into sequence of instructions.
    ## Performs the first optimisation: Grouping of Move and Add / Subtract instructions.

    let code = sanitizeCode(code)
    result = @[]

    var idx = 0

    template count(c: char): int =
        let startIdx = idx
        while idx < len(code) and code[idx] == c:
            inc idx
        idx - startIdx

    while idx < len(code):
        let instr = code[idx]
        inc idx

        case instr
        of '+':
            result.add(Instr(kind: opAdd, add: uint8(1 + count('+'))))
        of '-':
            result.add(Instr(kind: opSub, sub: uint8(1 + count('-'))))
        of '>':
            result.add(Instr(kind: opMove, move: 1 + count('>')))
        of '<':
            result.add(Instr(kind: opMove, move: -(1 + count('<'))))
        of '[':
            result.add(Instr(kind: opLoopStart))
        of ']':
            result.add(Instr(kind: opLoopEnd))
        of ',':
            result.add(Instr(kind: opRead))
        of '.':
            result.add(Instr(kind: opWrite))
        else: discard

    result.add(Instr(kind: opEnd))


proc addJumpInformation*(code: var seq[Instr]) =
    ## Adds the target jump location of each '[' and ']' instruction.
    var openBracketPosStack: seq[int] = @[]

    for idx, instr in code:
        if instr.kind == opLoopStart:
            openBracketPosStack.add(idx)
        elif instr.kind == opLoopEnd:
            if len(openBracketPosStack) == 0:
                continue

            let openBracket = openBracketPosStack.pop()
            code[openBracket].endPos = idx
            code[idx].startPos = openBracket


proc run*[T](code: seq[Instr], tape: var T, input, output: Stream) =
    ## Executes a sequence of instructions.
    ##
    ## Tape needs to support the following operations
    ## - tape.extendIfNecessary(targetPos: int)
    ## - tape[idx: int] -> uint8
    ## - tape[idx: int] = uint8
    ## - tape.safeAccess(idx: int) -> uint8
    ## - tape.safeAccess(idx: int) = uint8(20)

    var codePos: int = 0
    var tapePos: int = 0

    while true:
        {.push overflowchecks: off.}
        let instr = code[codePos]

        # echo codePos, " ", tapePos, " ", instr
        # echo codePos, " Tape ", tape, len(tape)

        case instr.kind
        of opAdd:
            tape[tapePos] += instr.add

        of opSub:
            tape[tapePos] -= instr.sub

        of opMove:
            tapePos += instr.move
            tape.extendIfNecessary(tapePos)

        of opWrite:
            output.write char(tape[tapePos])
            # echo tape[tapePos]

        of opRead:
            var input_char: uint8
            if input.atEnd:
                input_char = 0
            else:
                input_char = uint8(input.readChar())
            tape[tapePos] = input_char

        of opLoopStart:
            if tape[tapePos] == 0:
                codePos = instr.endPos

        of opLoopEnd:
            if tape[tapePos] != 0:
                codePos = instr.startPos

        of opClear:
            tape[tapePos] = 0

        of opScan:
            while tape[tapePos] != 0:
                tapePos += instr.scanStep
                tape.extendIfNecessary(tapePos)

        of opCopyAdd:
            tape.safeAccess(tapePos + instr.copyAddOffset) += tape[tapePos]

        of opCopySub:
            tape.safeAccess(tapePos + instr.copySubOffset) -= tape[tapePos]

        of opMulAdd:
            tape.safeAccess(tapePos + instr.mulAddOffset.tape) += tape[tapePos] * instr.mulAddOffset.cell

        of opMulSub:
            tape.safeAccess(tapePos + instr.mulSubOffset.tape) -= tape[tapePos] * instr.mulAddOffset.cell

        of opAddAtOffset:
            tape.safeAccess(tapePos + instr.addAtOffset.tape) += instr.addAtOffset.cell

        of opSubAtOffset:
            tape.safeAccess(tapePos + instr.subAtOffset.tape) -= instr.subAtOffset.cell

        of opSet:
            tape[tapePos] = instr.setValue

        of opEnd:
            break

        inc codePos
        {.pop.}


proc run*(code: seq[Instr], input, output: Stream) =
    # var tape: SeqTape
    # init(tape)
    # run[SeqTape](code, tape, input, output)
    var tape: UncheckedArrayTape
    init(tape)
    run[UncheckedArrayTape](code, tape, input, output)


proc optimize*(code: seq[Instr]): seq[Instr] =
    optimization.optimize(code, allOptimizers)


proc run*(code: string; input, output: Stream) =
    var instructions = parse(code)
    instructions = optimize(instructions)
    addJumpInformation(instructions)
    run(instructions, input, output)
