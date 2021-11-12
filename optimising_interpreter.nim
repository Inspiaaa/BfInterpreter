
import std/streams
import ./ir
import ./seqview
import ./pattern_matching


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
            # [-] and [+] are clear commands
            # if (peek(0) == '-' or peek(0) == '+') and peek(1) == ']':
            #     result.add(Instr(kind: opClear))
            #     idx += 2
            # else:
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

    var mulFactor: uint8 = 0

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
            let targetPos = tapePos + instr.copyAddOffset
            extendTapeIfNecessary(targetPos)
            tape[targetPos] += tape[tapePos]

        of opCopySub:
            let targetPos = tapePos + instr.copySubOffset
            extendTapeIfNecessary(targetPos)
            tape[targetPos] -= tape[tapePos]

        of opSetupMul:
            mulFactor = instr.mul

        of opMulAdd:
            let targetPos = tapePos + instr.mulAddOffset
            extendTapeIfNecessary(targetPos)
            tape[targetPos] += tape[tapePos] * mulFactor

        of opMulSub:
            let targetPos = tapePos + instr.mulSubOffset
            extendTapeIfNecessary(targetPos)
            tape[targetPos] -= tape[tapePos] * mulFactor

        of opNone:
            discard

        inc codePos
        {.pop.}


type PatternReplacement* = tuple[matchLen: int, pattern: seq[Instr]]
type Replacer* = proc (s: SeqView[Instr]): PatternReplacement {.closure.}


proc optimise*(
        code: seq[Instr],
        patterns: varargs[Replacer]): seq[Instr] =

    var optimized: seq[Instr] = @[]
    var view = initSeqView(code, 0..<len(code))

    var idx = 0
    while idx < len(code):
        var didReplace = false

        for pattern in patterns:
            view.moveTo(idx..<len(code))
            let (matchLen, replacement) = pattern(view)

            if matchLen > 0:
                optimized.add(replacement)
                idx += matchLen
                didReplace = true
                break

        if not didReplace:
            optimized.add(code[idx])
            idx += 1

    return optimized


proc optimiseClear*(s: SeqView[Instr]): PatternReplacement =
    # Optimises [-] and [+] to a single opClear instruction
    if matchPattern(s,
            opLoopStart,
            Instr(kind: opAdd, add: 1) or Instr(kind: opSub, sub: 1),
            opLoopEnd):
        return (3, @[Instr(kind: opClear)])


proc optimiseScan*(s: SeqView[Instr]): PatternReplacement =
    # Optimises [>], [<], [>>>>], ... to a single opScan instruction
    if matchPattern(s, opLoopStart, opMove, opLoopEnd):
        return (3, @[Instr(kind: opScan, scanStep: s[1].move)])

# Possible optimisation for [+>+]: Invert the current cell and then do the usual optimise move optimisation

proc optimiseMove*(s: SeqView[Instr]): PatternReplacement =
    # Optimises a [->+<] instruction to an opCopy and opClear
    # Instr: [->+<]
    # Idx:   012345

    if not matchPattern(s,
            opLoopStart,
            opSub,
            opMove,
            Instr(kind: opSub, sub: 1) or Instr(kind: opAdd, add: 1),
            opMove,
            opLoopEnd):
        return

    let moveA = s[2]
    let increment = s[3]
    let moveB = s[4]
    let loopStart = s[0]
    let loopEnd = s[5]

    if moveA.move != -moveB.move:
        return

    var copyInstr: Instr
    if increment == opAdd:
        copyInstr = Instr(kind: opCopyAdd, copyAddOffset: moveA.move)
    if increment == opSub:
        copyInstr = Instr(kind: opCopySub, copySubOffset: moveA.move)

    if copyInstr == opNone:
        return

    return (6, @[loopStart, copyInstr, Instr(kind: opClear), loopEnd])


proc getSimpleLoop(s: SeqView[Instr]): int =
    ## Returns the length of a basic loop, i.e. a loop that only consists of +, -, > and <, and
    ## where the total pointer movement must add up to 0.
    ## If this is not the case, it returns 0 for the length.

    if s[0] != opLoopStart:
        return 0

    var moveSum = 0
    var idx = 1
    while true:
        let instr = s[idx]
        if instr == opMove:
            moveSum += instr.move
        elif not (instr == opAdd or instr == opSub):
            break
        inc idx

    if s[idx] != opLoopEnd:
        return 0

    return idx + 1


proc optimiseMultiMul*(s: SeqView[Instr]): PatternReplacement =
    ## Optimises a multiplication loop to a simpler instruction set.
    ## E.g. [->+++<] (Add current cell * 3 to the cell to the right)
    ## => [ opClear, opStore, opMul ]

    if not matchPattern(s, opLoopStart, Instr(kind: opSub, sub: 1)):
        return

    let endIdx = getSimpleLoop(s) - 1
    if endIdx == -1:
        return

    let loopStart = s[0]
    let loopEnd = s[endIdx]

    var replacement: seq[Instr]

    template setupMul(factor: uint8) = replacement.add(Instr(kind: opSetupMul, mul: factor))
    template mulAdd(offset: int) = replacement.add(Instr(kind: opMulAdd, mulAddOffset: offset))
    template mulSub(offset: int) = replacement.add(Instr(kind: opMulSub, mulSubOffset: offset))
    template copyAdd(offset: int) = replacement.add(Instr(kind: opCopyAdd, copyAddOffset: offset))
    template copySub(offset: int) = replacement.add(Instr(kind: opCopySub, copySubOffset: offset))

    replacement.add(loopStart)

    var moveSum = 0
    # Skip the [-
    for instr in s[2..<endIdx]:
        case instr.kind
        of opAdd:
            if instr.add == 1:
                copyAdd(moveSum)
            else:
                setupMul(instr.add)
                mulAdd(moveSum)
        of opSub:
            if instr.sub == 1:
                copySub(moveSum)
            else:
                setupMul(instr.sub)
                mulSub(moveSum)
        of opMove:
            moveSum += instr.move
        else:
            discard
        # TODO: Check that the source cell (i.e. moveSum == 0) is not modified!

    replacement.add(Instr(kind: opClear))
    replacement.add(loopEnd)

    return (endIdx+1, replacement)
