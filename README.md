# Nim BFI

Optimizing interpreter for the esoteric [Brainf#@%](https://en.wikipedia.org/wiki/Brainfuck) programming language written in Nim.



### CLI Usage:

```
Usage:
  bfi [optional-params]
Options:
  -h, --help                     print this cligen-erated help
  --help-syntax                  advanced: prepend,plurals,..
  -f=, --file=    string  ""     Path to the file with the BF code
  -c=, --code=    string  ""     Directly enter BF code as a string
  -n, --noOpt     bool    false  Flag to disable optimizations
  -i=, --input=   string  ""     Path to the input data; Uses stdin if none specified
  -o=, --output=  string  ""     Path to the output file; Uses stdout if none specified
```



### CLI Examples:

```batch
# Execute code from a file
bfi -f examples/mandelbrot.bf

# Write the output to a file
bfi -f examples/mandelbrot.bf -o mandelbrot.txt

# Disable optimization
bfi -f examples/mandelbrot.bf -n
bfi -f examples/mandelbrot.bf --noOpt

# Execute a string directly, prints "Hello World!"
bfi -c "->+>>>+>>-[++++++[>+++++++++>+++++>+<<<-]<+]>>.>--.->++..>>+.>-[>.<<]>[>]<<+."
```



### Compilation

```batch
nimble install cligen
nim c --out:bfi.exe -d:release -d:danger src/cli.nim 
```

The `-d:danger` flag makes the program run faster at the cost of runtime checks. This flag can of course be omitted when compiling.

It uses `cligen` for making the command line interface.



### Using the Nim API

See the `example.nim` file for a full example.

```nim
import std/streams
import ./src/optimizing_interpreter

let code = """
"->+>>>+>>-[++++++[>+++++++++>+++++>+<<<-]<+]>>.>--.->++..>>+.>-[>.<<]>[>]<<+."
"""

# Option A:
run(code, newStringStream(""), newFileStream(stdout))


# Option B:
var instructions = parse(code)
instructions = optimize(instructions)
addJumpInformation(instructions)

# Inspect the optimized instructions
for i in instructions[0..<len(instructions)]:
    echo i

run(instructions, newStringStream(""), newFileStream(stdout))
```


