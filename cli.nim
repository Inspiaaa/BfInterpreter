
import std/streams

import ./optimizing_interpreter


proc cli(
        file: string = "",
        code: string = "",
        noOpt: bool = false,
        input: string = "",
        output: string = "") =

    if len(file) > 0 and len(code) > 0:
        raise newException(ValueError, "Either set file or code, not both.")

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


import cligen
dispatch(cli)