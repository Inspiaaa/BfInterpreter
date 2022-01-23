
import std/streams
import ./ir
import ./optimization


type SeqTape* = seq[uint8]

proc init*(self: var SeqTape) =
    self.add(0'u8)

template extendIfNecessary*(self: SeqTape, targetPos: int) =
    while len(self) <= targetPos:
        self.add(0)


type ArrayTape* = array[30000, uint8]
proc init*(self: var ArrayTape) = discard
template extendIfNecessary*(self: ArrayTape, targetPos: int) = discard


type UncheckedArrayTape* = object
    data*: ptr UncheckedArray[uint8]

proc init*(self: var UncheckedArrayTape, size: int = 30000) =
    self.data = cast[ptr UncheckedArray[uint8]](alloc0(size))

proc `=destroy`*(self: var UncheckedArrayTape) =
    dealloc(self.data)

template extendIfNecessary*(self: UncheckedArrayTape, targetPos: int) =
    discard

template `[]=`*(self: UncheckedArrayTape, index: int, value: uint8): untyped =
    self.data[index] = value

template `[]`*(self: UncheckedArrayTape, index: int): untyped =
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

    var idx: TPos = 0

    template count(c: char): TPos =
        let startIdx = idx
        while idx < len(code) and code[idx] == c:
            inc idx
        idx - startIdx

    while idx < len(code):
        let instr = code[idx]
        inc idx

        case instr
        of '+':
            result.add(Instr(kind: opAdd, value: uint8(1 + count('+'))))
        of '-':
            result.add(Instr(kind: opSub, value: uint8(1 + count('-'))))
        of '>':
            result.add(Instr(kind: opMove, pos: 1 + count('>')))
        of '<':
            result.add(Instr(kind: opMove, pos: -(1 + count('<'))))
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
            code[openBracket].pos = idx.TPos
            code[idx].pos = openBracket.TPos


proc run*[T](code: seq[Instr], tape: var T, input, output: Stream) =
    ## Executes a sequence of instructions.
    ##
    ## Tape needs to support the following operations
    ## - tape.extendIfNecessary(targetPos: int)
    ## - tape[idx: int] -> uint8
    ## - tape[idx: int] = uint8

    template safeAccess(self: T, targetPos: int): untyped =
        self.extendIfNecessary(targetPos)
        self[targetPos]

    var codePos: int = 0
    var tapePos: TPos = 0

    while true:
        {.computedGoto.}
        {.push overflowchecks: off.}
        let instr = code[codePos]

        # echo codePos, " ", tapePos, " ", instr
        # echo codePos, " Tape ", tape, len(tape)

        case instr.kind
        of opAdd:
            tape[tapePos] += instr.value

        of opSub:
            tape[tapePos] -= instr.value

        of opMove:
            tapePos += instr.pos
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
                codePos = instr.pos

        of opLoopEnd:
            if bool(tape[tapePos]):
                codePos = instr.pos

        of opClear:
            tape[tapePos] = 0

        of opScan:
            while bool(tape[tapePos]):
                tapePos += instr.scanStep
                tape.extendIfNecessary(tapePos)

        of opCopyAdd:
            tape.safeAccess(tapePos + instr.offset) += tape[tapePos]

        of opCopySub:
            tape.safeAccess(tapePos + instr.offset) -= tape[tapePos]

        of opMulAdd:
            tape.safeAccess(tapePos + instr.offset) += tape[tapePos] * instr.factor

        of opMulSub:
            tape.safeAccess(tapePos + instr.offset) -= tape[tapePos] * instr.factor

        of opAddAtOffset:
            tape.safeAccess(tapePos + instr.offset) += instr.value

        of opSubAtOffset:
            tape.safeAccess(tapePos + instr.offset) -= instr.value

        of opSet:
            tape[tapePos] = instr.value

        of opEnd:
            break

        inc codePos
        {.pop.}


proc optimize*(code: seq[Instr]): seq[Instr] =
    optimization.optimize(code, allOptimizers)


proc run*(code: seq[Instr], input, output: Stream, tapeSize = 30000) =
    if tapeSize == -1:
        var tape: SeqTape
        init(tape)
        run[SeqTape](code, tape, input, output)
    else:
        var tape: UncheckedArrayTape
        init(tape, tapeSize)
        run[UncheckedArrayTape](code, tape, input, output)


proc run*(code: string, input, output: Stream, tapeSize = 30000) =
    var instructions = parse(code)
    instructions = optimize(instructions)
    addJumpInformation(instructions)
    run(instructions, input, output, tapeSize)
