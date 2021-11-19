
import std/strutils
import times
import terminal
import macros


proc sum[T](values: openarray[T]): T =
    var total: T
    for val in values:
        total += val
    return total


proc variance(values: openArray[float]): float =
    let mean = sum(values) / float(len(values))

    var variance: float = 0
    for val in values:
        variance += (val - mean) * (val - mean)
    variance /= float(len(values))

    return variance


iterator progressBar(steps: int): int =
    stdout.writeLine("")

    const length = 10
    for i in 1..steps:
        let barsToShow = int(length * i/steps)
        stdout.eraseLine()
        stdout.write("[", repeat('8', barsToShow), repeat(' ', length - barsToShow), "]")
        stdout.flushFile()
        yield i

    stdout.eraseLine()


macro benchmark(name: string, count: int = 5, code: untyped): untyped =
    return quote do:
        var times: seq[float]

        for i in progressBar(`count`):
            let startTime = cpuTime()
            `code`
            let elapsedTime = cpuTime() - startTime
            times.add(elapsedTime)
            echo elapsedTime

        echo()
        echo `name`
        echo repeat('-', len(`name`))
        echo "Min: ", min(times), "s"
        echo "Max: ", max(times), "s"
        echo "Mean: ", sum(times) / float(len(times)), "s"
        echo "Variance: ", variance(times), "s"
        echo()


import ../src/optimizing_interpreter
import ../src/naive_interpreter
import ../src/silent_stream
import std/streams

let hanoi = readFile("examples/hanoi.bf")
let mandelbrot = readFile("examples/mandelbrot.bf")


benchmark "Hanoi", 20:
    var stream = newSilentStream()
    optimizing_interpreter.run(hanoi, newStringStream(""), stream)

benchmark "Hanoi Unoptimized", 3:
    var stream = newSilentStream()
    naive_interpreter.run(hanoi, newStringStream(""), stream)


benchmark "Mandelbrot":
    var stream = newSilentStream()
    optimizing_interpreter.run(mandelbrot, newStringStream(""), stream)

benchmark "Mandelbrot Unoptimized", 3:
    var stream = newSilentStream()
    naive_interpreter.run(mandelbrot, newStringStream(""), stream)
