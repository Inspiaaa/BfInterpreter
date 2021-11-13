
import std/streams
import ./ir
import ./optimization


# 3.63s for mandelbrot


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
    ## Converts a string brainfuck code into sequence of instructions.
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


proc run*(code: seq[Instr]; input, output: Stream) =
    ## Executes a sequence of instructions.

    var tape: seq[uint8] = @[0u8]

    var codePos: int = 0
    var tapePos: int = 0

    template extendTapeIfNecessary(targetLen: int) =
        while targetLen >= len(tape):
            tape.add(0)

    template safeAccess(targetPos: int): untyped =
        extendTapeIfNecessary(targetPos)
        tape[targetPos]

    while codePos < len(code):
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
            extendTapeIfNecessary(tapePos)

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
                extendTapeIfNecessary(tapePos)

        of opCopyAdd:
            safeAccess(tapePos + instr.copyAddOffset) += tape[tapePos]

        of opCopySub:
            safeAccess(tapePos + instr.copySubOffset) -= tape[tapePos]

        of opMulAdd:
            safeAccess(tapePos + instr.mulAddOffset.tape) += tape[tapePos] * instr.mulAddOffset.cell

        of opMulSub:
            safeAccess(tapePos + instr.mulSubOffset.tape) -= tape[tapePos] * instr.mulAddOffset.cell

        of opAddAtOffset:
            safeAccess(tapePos + instr.addAtOffset.tape) += instr.addAtOffset.cell

        of opSubAtOffset:
            safeAccess(tapePos + instr.subAtOffset.tape) -= instr.subAtOffset.cell

        of opSet:
            tape[tapePos] = instr.setValue

        of opNone:
            discard

        inc codePos
        {.pop.}


proc optimize*(code: seq[Instr]): seq[Instr] =
    optimization.optimize(code, allOptimizers)


proc run*(code: string; input, output: Stream, opt: bool = true) =
    var instructions = parse(code)
    if opt:
        instructions = optimize(instructions)
    addJumpInformation(instructions)
    run(instructions, input, output)
