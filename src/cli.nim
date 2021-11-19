
from os import fileExists
import std/streams
import std/terminal
import cligen

import ./optimizing_interpreter
import ./naive_interpreter


template getCode(file: string, code: string): string =
    if len(file) > 0 and len(code) > 0:
        stdout.styledWriteLine(fgRed, "CLI Error: Either set file (-f) or code (-c), not both.")
        return

    if len(file) > 0:
        readFile(file)
    else:
        code


proc r(
        file: string = "",
        code: string = "",
        noOpt: bool = false,
        input: string = "",
        output: string = "",
        silent: bool = false) =
    ## Runs the interpreter.

    let code = getCode(file, code)

    let inputStream = (
        if fileExists(input): newFileStream(input, fmRead)
        else: newStringStream(input))

    let outputStream = (
        if silent: newStringStream("")
        else: (
            if len(output) > 0: newFileStream(output, fmWrite)
            else: newFileStream(stdout)
        )
    )

    if noOpt:
        naive_interpreter.run(code, inputStream, outputStream)
    else:
        optimizing_interpreter.run(code, inputStream, outputStream)


proc inspect(
        file: string = "",
        code: string = "",
        output: string = "",
        number: int = -1) =
    ## Prints the first n instructions of the optimized code.

    let code = getCode(file, code)
    var instructions = optimizing_interpreter.parse(code)
    instructions = optimizing_interpreter.optimize(instructions)
    optimizing_interpreter.addJumpInformation(instructions)

    let outputStream = (
        if len(output) > 0: newFileStream(output, fmWrite)
        else: newFileStream(stdout))

    let number = if number == -1: len(instructions) else: number
    for i in 0..<number:
        outputStream.writeLine(instructions[i])


dispatchMulti(
    [
        r,
        help = {
            "file": "Path to the file with the BF code",
            "code": "Directly enter BF code as a string",
            "noOpt": "Flag to disable optimizations",
            "input": "Path to the input data; Uses stdin if none specified",
            "output": "Path to the output file; Uses stdout if none specified",
            "silent": "Flag that, when provided, prevents the interpreter from outputting any text",
        }
    ],
    [
        inspect
    ]
)
