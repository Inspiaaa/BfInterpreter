
import std/streams
import times


# 6.25s for mandelbrot


type
    InstrKind = enum opAdd, opSub, opMove, opLoopStart, opLoopEnd, opRead, opWrite, opClear
    Instr = ref object
        case kind: InstrKind
        of opAdd:
            add: uint8
        of opSub:
            sub: uint8
        of opMove:
            move: int
        of opLoopStart:
            endPos: int
        of opLoopEnd:
            startPos: int
        of opRead, opWrite, opClear: discard


proc sanitizeCode(code: string): string =
    ## Removes characters that are not instructions
    var sanitized: string = ""

    for c in code:
        case c
        of '+', '-', '<', '>', '[', ']', '.', ',':
            sanitized.add(c)
        else: discard

    return sanitized


proc parse(code: string): seq[Instr] =
    let code = sanitizeCode(code)
    result = @[]

    var idx = 0

    template count(c: char, maxCount: int = 1000): int =
        let startIdx = idx
        while idx < len(code) and code[idx] == c: inc idx
        idx - startIdx

    template peek(offset=1): char =
        if idx + offset > len(code): '?' else: code[idx + offset]

    while idx < len(code):
        let instr = code[idx]
        inc idx

        case instr
        of '+':
            result.add(Instr(kind: opAdd, add: uint8(1 + count('+', maxCount=254))))
        of '-':
            result.add(Instr(kind: opSub, sub: uint8(1 + count('-', maxCount=254))))
        of '>':
            result.add(Instr(kind: opMove, move: 1 + count('>')))
        of '<':
            result.add(Instr(kind: opMove, move: -(1 + count('<'))))
        of '[':
            # [-] and [+] are clear commands
            if (peek(0) == '-' or peek(0) == '+') and peek(1) == ']':
                result.add(Instr(kind: opClear))
                idx += 2
            else:
                result.add(Instr(kind: opLoopStart))
        of ']':
            result.add(Instr(kind: opLoopEnd))
        of ',':
            result.add(Instr(kind: opRead))
        of '.':
            result.add(Instr(kind: opWrite))
        else: discard


proc addJumpInformation(code: seq[Instr]) =
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


proc run(code: seq[Instr]; input, output: Stream) =
    var tape: seq[uint8] = @[0u8]

    var codePos: int = 0
    var tapePos: int = 0

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
            while tapePos >= len(tape):
                tape.add(0)

        of opWrite:
            output.write char(tape[tapePos])

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

        inc codePos


import std/macros

macro timeit(code: untyped): untyped =
    result = quote do:
        block:
            let startTime = epochTime()
            `code`
            let elapsedTime = epochTime() - startTime
            echo()
            echo "Time: ", elapsedTime


echo sizeof Instr(kind: opAdd)[]
let Instrs = parse(readFile("bf/mandelbrot.bf"))

timeit:
    addJumpInformation(Instrs)

# for i in Instrs[0..50]:
#      echo repr i

timeit:
    run(Instrs, newStringStream("Hello"), newFileStream(stdout))
