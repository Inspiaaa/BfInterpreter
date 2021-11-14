
import std/streams
import std/terminal
import cligen

import ./optimizing_interpreter
import ./naive_interpreter


proc bfi(
        file: string = "",
        code: string = "",
        noOpt: bool = false,
        input: string = "",
        output: string = "") =

    if len(file) > 0 and len(code) > 0:
        stdout.styledWriteLine(fgRed, "CLI Error: Either set file (-f) or code (-c), not both.")
        return

    let code: string = (
        if len(file) > 0: readFile(file)
        else: code)

    # TODO: If input is not a file, use it as a string stream.
    let inputStream = (
        if len(input) > 0: newFileStream(input, fmRead)
        else: newFileStream(stdin))

    let outputStream = (
        if len(output) > 0: newFileStream(output, fmWrite)
        else: newFileStream(stdout))

    if noOpt:
        naive_interpreter.run(code, inputStream, outputStream)
    else:
        optimizing_interpreter.run(code, inputStream, outputStream)


dispatch(
    bfi,
    help = {
        "file": "Path to the file with the BF code",
        "code": "Directly enter BF code as a string",
        "noOpt": "Flag to disable optimizations",
        "input": "Path to the input data; Uses stdin if none specified",
        "output": "Path to the output file; Uses stdout if none specified"
    }
)
