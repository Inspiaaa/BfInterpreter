
import std/streams
import std/terminal
import cligen

import ./optimizing_interpreter


proc cli(
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

    let inputStream = (
        if len(input) > 0: newFileStream(input, fmRead)
        else: newFileStream(stdin))

    let outputStream = (
        if len(output) > 0: newFileStream(output, fmWrite)
        else: newFileStream(stdout))

    run(code, inputStream, outputStream, opt=not noOpt)


dispatch(cli)