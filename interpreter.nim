
import times
import std/streams


# 128.77s for mandelbrot


proc createJumpTable(code: string): seq[int] =
    var openBracketPosStack: seq[int] = @[]
    var jumpTable: seq[int] = newSeq[int](len(code))

    for idx, c in code:
        if c == '[':
            openBracketPosStack.add(idx)
        if c == ']':
            if len(openBracketPosStack) == 0:
                continue
            let openBracket = openBracketPosStack.pop()
            jumpTable[idx] = openBracket
            jumpTable[openBracket] = idx

    return jumpTable


proc run(code: string; input, output: Stream) =
    var tape: seq[uint8] = @[0u8]
    let jumpTable: seq[int] = createJumpTable(code)

    var codePos: int = 0
    var tapePos: int = 0

    while codePos < len(code):
        let c: char = code[codePos]

        # echo c, " Tape ", tape, len(tape)

        case c
        of '>':
            inc tapePos
            if tapePos >= len(tape):
                tape.add(0)

        of '<': dec tapePos
        of '+': inc tape[tapePos]
        of '-': dec tape[tapePos]
        of '.':
            output.write char(tape[tapePos])

        of ',':
            var input_char: uint8
            if input.atEnd:
                input_char = 0
            else:
                input_char = uint8(input.readChar())
            tape[tapePos] = input_char

        of '[':
            if tape[tapePos] == 0:
                codePos = jumpTable[codePos]

        of ']':
            if tape[tapePos] != 0:
                codePos = jumpTable[codePos]

        else: discard
        inc codePos


let code: string = readFile("bf/mandelbrot.bf")
let startTime = epochTime()
run(code, newStringStream("Hello"), newFileStream(stdout))
let elapsedTime = epochTime() - startTime
echo()
echo "Time: ", elapsedTime