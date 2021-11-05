
import std/streams
import times


# 6.25s for mandelbrot


type
    InstructionKind = enum opAdd, opSub, opMove, opLoopStart, opLoopEnd, opRead, opWrite, opClear
    Instruction = ref object
        case kind: InstructionKind
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
    # var sanitized: seq[char]: @[]
    var sanitized: string = ""

    for c in code:
        case c
        of '+', '-', '<', '>', '[', ']', '.', ',':
            sanitized.add(c)
        else: discard

    return sanitized


proc parse(code: string): seq[Instruction] =
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
            result.add(Instruction(kind: opAdd, add: uint8(1 + count('+', maxCount=254))))
        of '-':
            result.add(Instruction(kind: opSub, sub: uint8(1 + count('-', maxCount=254))))
        of '>':
            result.add(Instruction(kind: opMove, move: 1 + count('>')))
        of '<':
            result.add(Instruction(kind: opMove, move: -(1 + count('<'))))
        of '[':
            if (peek(0) == '-' or peek(0) == '+') and peek(1) == ']':
                result.add(Instruction(kind: opClear))
                idx += 2
            else:
                result.add(Instruction(kind: opLoopStart))
        of ']':
            result.add(Instruction(kind: opLoopEnd))
        of ',':
            result.add(Instruction(kind: opRead))
        of '.':
            result.add(Instruction(kind: opWrite))
        else: discard


proc addJumpInformation(code: seq[Instruction]) =
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


proc run(code: seq[Instruction]; input, output: Stream) =
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

        else: discard
        inc codePos


let startTime = epochTime()

let instructions = parse(readFile("bf/mandelbrot.bf"))
addJumpInformation(instructions)

# for i in instructions[0..50]:
#      echo repr i

run(instructions, newStringStream("Hello"), newFileStream(stdout))

let elapsedTime = epochTime() - startTime
echo()
echo "Time: ", elapsedTime
