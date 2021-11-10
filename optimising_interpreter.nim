
import std/streams
import ./ir
import ./seqview


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
    var tape: seq[uint8] = @[0u8]

    var codePos: int = 0
    var tapePos: int = 0

    template extendTapeIfNecessary(targetLen: int) =
        while targetLen >= len(tape):
                tape.add(0)

    while codePos < len(code):
        let instr = code[codePos]

        # echo c, " Tape ", tape, len(tape)

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

        of opNone:
            discard

        inc codePos


type PatternReplacement* = tuple[matchLen: int, pattern: seq[Instr]]
type Replacer* = proc (s: SeqView[Instr]): PatternReplacement {.closure.}


proc optimise*(
        code: seq[Instr],
        patterns: varargs[Replacer]): seq[Instr] =

    var optimized: seq[Instr] = @[]
    var view = initSeqView(code, 0..len(code))

    var idx = 0
    while idx < len(code):
        var didReplace = false

        for pattern in patterns:
            view.moveTo(idx..(len(code) - 1))
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
    if (s[0] == opLoopStart and
        (s[1] == Instr(kind: opAdd, add: 1) or s[1] == Instr(kind: opSub, sub: 1) and
        s[2] == opLoopEnd)):
        return (3, @[Instr(kind: opClear)])

proc optimiseScan*(s: SeqView[Instr]): PatternReplacement =
    # Optimises [>], [<], [>>>>], ... to a single opScan instruction
    if (s[0] == opLoopStart and
        s[1] == opMove and
        s[2] == opLoopEnd):
        return (3, @[Instr(kind: opScan, scanStep: s[1].move)])

# Possible optimisation for [+>+]: Invert the current cell and then do the usual optimise move optimisation

proc optimiseMove*(s: SeqView[Instr]): PatternReplacement =
    # Optimises a [->+<] instruction to an opCopy and opClear
    # Instr: [->+<]
    # Idx:   012345
    if s[0] != opLoopStart or s[1] != opSub or s[5] != opLoopEnd:
        return

    let moveA = s[2]
    let increment = s[3]
    let moveB = s[4]

    if moveA != opMove or moveB != opMove:
        return

    if moveA.move != -moveB.move:
        return

    if increment == opAdd and increment.add == 1:
        return (6, @[Instr(kind: opCopyAdd, copyAddOffset: moveA.move), Instr(kind: opClear)])
    if increment == opSub and increment.sub == 1:
        return (6, @[Instr(kind: opCopySub, copySubOffset: moveA.move), Instr(kind: opClear)])
