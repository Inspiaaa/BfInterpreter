
import std/streams
import sugar
import times


# 4.84s for mandelbrot


type
    InstrKind = enum
        opAdd,
        opSub,
        opMove,
        opLoopStart,
        opLoopEnd,
        opRead,
        opWrite,
        opClear,
        opScan,  # Moves to the next empty (0) cell to the right / left by jumping certain increments
        opNone  # Used to avoid errors when doing pattern matching at the end of the instruction string

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
        of opScan:
            scanStep: int
        of opNone: discard


proc `==`(a: Instr, kind: InstrKind): bool =
    a.kind == kind

proc `==`(a: Instr, b: Instr): bool =
    if a.kind != b.kind:
        return false

    case a.kind
    of opAdd:
        return a.add == b.add
    of opSub:
        return a.sub == b.sub
    of opMove:
        return a.move == b.move
    of opLoopStart:
        return a.startPos == b.startPos
    of opLoopEnd:
        return a.endPos == b.endPos
    else:
        return true


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

    template count(c: char): int =
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

        of opScan:
            while tape[tapePos] != 0:
                tapePos += instr.scanStep
                while tapePos >= len(tape):
                    tape.add(0)

        of opNone:
            discard

        inc codePos


type SeqView[T] = object
    data: ref seq[T]
    bounds: Slice[int]

proc seqView*[T](s: seq[T], bounds: Slice): SeqView[T] =
    var refSeq: ref seq[T]
    new(refSeq)
    shallowCopy(refSeq[], s)
    return SeqView[T](data: refSeq, bounds: bounds)

proc moveViewTo*[T](s: SeqView[T], newBounds: Slice): SeqView[T] =
    SeqView[T](data: s.data, bounds: newBounds)

proc moveViewLowerBy*[T](s: SeqView[T], offset: int): SeqView[T] =
    SeqView[T](data: s.data, bounds: (s.bounds.a + offset)..s.bounds.b)

proc `[]`*[T](s: SeqView[T], idx: int): T =
    s.data[idx + s.bounds.a]

proc `[]`*(s: SeqView[Instr], idx: int): Instr =
    if not ((idx+s.bounds.a) in s.bounds):
        return Instr(kind: opNone)
    return s.data[idx + s.bounds.a]

iterator items*[T](s: SeqView[T]): T =
    for idx in s.bounds:
        yield s.data[idx]

proc len*[T](s: SeqView[T]): int =
    return s.bounds.b - s.bounds.a

type PatternReplacement = tuple[matchLen: int, pattern: seq[Instr]]
type Replacer = proc (s: SeqView[Instr]): PatternReplacement {.closure.}


proc optimise(
        code: seq[Instr],
        patterns: varargs[Replacer]): seq[Instr] =

    var optimized: seq[Instr] = @[]
    var view = seqView(code, 0..len(code))

    var idx = 0
    while idx < len(code):
        var didReplace = false

        for pattern in patterns:
            view = moveViewTo(view, idx..(len(code) - 1))
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


proc optimiseClear(s: SeqView[Instr]): PatternReplacement =
    if (s[0] == opLoopStart and
        (s[1] == Instr(kind: opAdd, add: 1) or s[1] == Instr(kind: opSub, sub: 1) and
        s[2] == opLoopEnd)):
        return (3, @[Instr(kind: opClear)])

proc optimiseScan(s: SeqView[Instr]): PatternReplacement =
    if (s[0] == opLoopStart and
        s[1] == opMove and
        s[2] == opLoopEnd):
        return (3, @[Instr(kind: opScan, scanStep: s[1].move)])


import std/macros

macro timeit(code: untyped): untyped =
    result = quote do:
        block:
            let startTime = epochTime()
            `code`
            let elapsedTime = epochTime() - startTime
            echo()
            echo "Time: ", elapsedTime


var instructions = parse(readFile("bf/mandelbrot.bf"))

timeit:
    let replacements: seq[Replacer] = @[Replacer(optimiseClear), Replacer(optimiseScan)]
    instructions = optimise(instructions, replacements)
    addJumpInformation(instructions)

# for i in instructions[0..50]:
#     echo repr i

timeit:
    run(instructions, newStringStream("Hello"), newFileStream(stdout))
