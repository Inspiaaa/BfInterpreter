# Nim BFI

Optimising interpreter for the esoteric [Brainf#@%](https://en.wikipedia.org/wiki/Brainfuck) programming language written in Nim.

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
import ./src/ir
var instructions: seq[Instr] = parse(code)
instructions = optimize(instructions)
addJumpInformation(instructions)

# Inspect the optimized instructions
for i in instructions[0..<len(instructions)]:
    echo i

run(instructions, newStringStream(""), newFileStream(stdout))
```

# Optimiser

This project executes BF code with an interpreter. 

One of the tricks to increase the performance of an interpreted language is by interpreting less, i.e. spending less time interpreting instructions and more time actually doing something meaningful. Generally higher-level interpreted languages are faster than lower-level interpreted languages, as they can achieve the same result with fewer instructions, meaning that more of the functionality is implemented in the optimised interpreted code instead of emulated via instructions.

This is also the fundamental idea of many BF optimisers: To reduce common patterns to single instructions that are efficiently implemented in the underlying language, here: Nim.

For example, to increment the current cell by 4, in BF you'd write: `++++`. The optimised code is: `Add(4)` (One instruction, not four).

#### Normal instructions

| Instruction | Meaning                                                             |
| ----------- | ------------------------------------------------------------------- |
| `>`         | Move the pointer to the right by 1 block.                           |
| `<`         | Move the pointer to the left by 1 block.                            |
| `+`         | Increment the current block.                                        |
| `-`         | Decrement the current block.                                        |
| `[`         | Jump to the corresponding `]` if the current block is `0`.          |
| `]`         | Jump back to the corresponding `[` if the current block is not `0`. |
| `.`         | Write the current block as an ASCII character.                      |
| `,`         | Read one byte from the input stream into the current block.         |

#### Expanded instruction set ([ir.nim](https://github.com/Inspiaaa/BfInterpreter/blob/master/src/ir.nim))

| Instruction   | BF Example           | Meaning                                                                  |
| ------------- | -------------------- | ------------------------------------------------------------------------ |
| opAdd         | `+`, `+++`           | Performs multiple `+` instructions at once.                              |
| opSub         | `-`, `---`           | ...                                                                      |
| opMove        | `>`, `<`, `>>>`      | Performs multiple `>` or `<` instructions at once.                       |
| opLoopStart   | `[`                  |                                                                          |
| opLoopEnd     | `]`                  |                                                                          |
| opWrite       | `.`                  |                                                                          |
| opRead        | `,`                  |                                                                          |
| opClear       | `[-]`,`[+]`          | Clears the current cell.                                                 |
| opSet         | `[-]+++`             | Sets the current cell to a value.                                        |
| opScan        | `[>]`,`[<]`, `[>>>]` | Moves to the next empty cell by jumping certain increments.              |
| opCopyAdd     | `[->+<]`             | Adds the current cell to another cell.                                   |
| opCopySub     | `[->-<]`             | Subtracts ...                                                            |
| opMulAdd      | `[->+++<]`           | Adds the current cell times a multiplication factor to another cell.     |
| opMulSub      | `[->---<]`           | Subtracts ...                                                            |
| opAddAtOffset | `>>>+`, `<+++`       | Adds the current cell to another cell without changing the cell pointer. |
| opSubAtOffset | `>>>-`, `<---`       | Subtracts ...                                                            |

#### Optimisation phases

1. **Parsing**
   
   Converts the string instructions into `Instr` objects. Already fuses multiple `+`,`-`, `>` and `<` instructions into one instruction (opAdd, opSub, and opMove, respectively). This makes subsequent the optimisation phase faster and simpler.

2. **Advanced optimisations**
   
   1. Clear loops
   
   2. Scan loops
   
   3. Copy loops
   
   4. Multiplication loops
   
   5. "Lazy movements" (Operation at an offset)

3. **Jump table creation**
   
   In order to not have to search for the corresponding bracket of a `[` and `]` instruction, precompute the target jump locations before executing the program. E.g. First `[` instruction jumps to index 10...

4. **Execution**



#### Further reading

https://www.nayuki.io/page/optimizing-brainfuck-compiler

http://calmerthanyouare.org/2015/01/07/optimizing-brainfuck.html

[Basics of BrainFuck · GitHub](https://gist.github.com/roachhd/dce54bec8ba55fb17d3a)


