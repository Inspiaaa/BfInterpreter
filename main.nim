
import std/macros
import std/streams
import times

import ./optimizing_interpreter


macro timeit(code: untyped): untyped =
    result = quote do:
        block:
            let startTime = epochTime()
            `code`
            let elapsedTime = epochTime() - startTime
            echo()
            echo "Time: ", elapsedTime


let code = readFile("bf/mandelbrot.bf")
var instructions = parse(code)
instructions = optimize(instructions)
addJumpInformation(instructions)

# for i in instructions[0..min(50, len(instructions)-1)]:
#     echo i

timeit:
    run(instructions, newStringStream("10"), newFileStream(stdout))
