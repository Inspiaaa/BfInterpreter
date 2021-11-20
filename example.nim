
import std/macros
import std/streams
import times

import ./src/optimizing_interpreter


macro timeit(message: string, code: untyped): untyped =
    result = quote do:
        let startTime = cpuTime()
        `code`
        let elapsedTime = cpuTime() - startTime
        echo()
        echo `message`, " ", elapsedTime, "s"


let code = readFile("examples/mandelbrot.bf")

timeit "Parse time:":
    var instructions = parse(code)
    instructions = optimize(instructions)
    addJumpInformation(instructions)

# Inspect the optimised instructions:
# for i in instructions[0..<min(50, len(instructions))]:
#     echo i

timeit "Execution time:":
    run(instructions, newStringStream("Input here"), newFileStream(stdout))
