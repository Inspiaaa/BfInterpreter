
import times

const code: string = readFile("bf/mandelbrot.bf")


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


const input: string = "Hello"
var input_idx = 0


var tape: seq[uint8] = @[0u8]
let jumpTable: seq[int] = createJumpTable(code)


var codePos: int = 0
var tapePos: int = 0

let startTime = epochTime()

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
        stdout.write char(tape[tapePos])
        # stdout.write tape[tapePos], " "

    of ',':
        var input_char: uint8
        if input_idx < len(input):
            input_char = uint8(input[input_idx])
        else:
            input_char = 0
        tape[tapePos] = input_char

    of '[':
        if tape[tapePos] == 0:
            codePos = jumpTable[codePos]

    of ']':
        if tape[tapePos] != 0:
            codePos = jumpTable[codePos]

    else: discard
    inc codePos


let elapsedTime = epochTime() - startTime
echo()
echo "Time: ", elapsedTime