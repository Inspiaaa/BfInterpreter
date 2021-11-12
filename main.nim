
import std/macros
import std/streams
import times

import ./optimising_interpreter


macro timeit(code: untyped): untyped =
    result = quote do:
        block:
            let startTime = epochTime()
            `code`
            let elapsedTime = epochTime() - startTime
            echo()
            echo "Time: ", elapsedTime


var instructions = parse(readFile("bf/mandelbrot.bf"))
# var instructions = parse("+++[->+++>>>---<<<<].>.>.>.>.>")

timeit:
    let replacements: seq[Replacer] = @[Replacer(optimiseClear), Replacer(optimiseScan), Replacer(optimiseMove), Replacer(optimiseMultiMul)]
    instructions = optimise(instructions, replacements)
    addJumpInformation(instructions)

for i in instructions[0..min(50, len(instructions)-1)]:
    echo i

timeit:
    run(instructions, newStringStream("Hello"), newFileStream(stdout))
