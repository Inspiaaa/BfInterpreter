
import ./seqview
import ./pattern_matching
import ./ir

type PatternReplacement* = tuple[matchLen: int, pattern: seq[Instr]]
type Replacer* = proc (s: SeqView[Instr]): PatternReplacement {.closure.}


proc optimize*(
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


proc optimizeClear*(s: SeqView[Instr]): PatternReplacement =
    # Optimizes [-] and [+] to a single opClear instruction
    if matchPattern(s,
            opLoopStart,
            Instr(kind: opAdd, add: 1) or Instr(kind: opSub, sub: 1),
            opLoopEnd):
        return (3, @[Instr(kind: opClear)])


proc optimizeScan*(s: SeqView[Instr]): PatternReplacement =
    # Optimizes [>], [<], [>>>>], ... to a single opScan instruction
    if matchPattern(s, opLoopStart, opMove, opLoopEnd):
        return (3, @[Instr(kind: opScan, scanStep: s[1].move)])


# Possible optimization for [+>+]: Invert the current cell and then do the usual optimize move optimization

proc optimizeMove*(s: SeqView[Instr]): PatternReplacement =
    # Optimizes a [->+<] instruction to an opCopy and opClear
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


proc optimizeMultiMul*(s: SeqView[Instr]): PatternReplacement =
    ## Optimizes a multiplication loop to a simpler instruction set.
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

    template mulAdd(offset: int, factor: uint8) =
        replacement.add(Instr(kind: opMulAdd, mulAddOffset: ValueWithOffset(cell: factor, tape: offset)))
    template mulSub(offset: int, factor: uint8) =
        replacement.add(Instr(kind: opMulSub, mulSubOffset: ValueWithOffset(cell: factor, tape: offset)))
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
                mulAdd(moveSum, instr.add)
        of opSub:
            if instr.sub == 1:
                copySub(moveSum)
            else:
                mulSub(moveSum, instr.sub)
        of opMove:
            moveSum += instr.move
        else:
            discard
        # TODO: Check that the source cell (i.e. moveSum == 0) is not modified!

    replacement.add(Instr(kind: opClear))
    replacement.add(loopEnd)

    return (endIdx+1, replacement)


proc optimizeLazyMoves*(s: SeqView[Instr]): PatternReplacement =
    ## Only moves the tape pointer after doing multiple operations.
    ##
    ## E.g.
    ## >>+<+>>>+
    ## => Add 1 at offset 2, Add 1 at offset 1, Add one at offset 4, Move pointer to 4

    var replacement: seq[Instr]
    var moveSum = 0
    var idx = 0

    while true:
        let instr = s[idx]
        case instr.kind
        of opMove:
            moveSum += instr.move
        of opAdd:
            replacement.add(Instr(
                kind: opAddAtOffset,
                addAtOffset: ValueWithOffset(cell: instr.add, tape: moveSum)))
        of opSub:
            replacement.add(Instr(
                kind: opSubAtOffset,
                subAtOffset: ValueWithOffset(cell: instr.sub, tape: moveSum)))
        else:
            break
        inc idx

    if len(replacement) >= 2:
        if moveSum != 0:
            replacement.add(Instr(kind: opMove, move: moveSum))
        return (idx, replacement)


const allOptimizers*: seq[Replacer] = @[
    Replacer(optimizeClear),
    Replacer(optimizeScan),
    Replacer(optimizeMove),
    Replacer(optimizeMultiMul),
    Replacer(optimizeLazyMoves)
]
