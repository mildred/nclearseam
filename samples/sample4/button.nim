import ../../src/nclearseam
import ../../src/nclearseam/util
import ../../src/nclearseam/dom
import jsconsole

type ButtonData* = ref object
  times*: int

proc times(d: ButtonData): string = $d.times

proc compileButton*(node: dom.Node): Component[ButtonData] =
  result = compile(ButtonData, node) do(b: auto):
    b.match(".times", times, eql).refresh(setText)
    b.match("button").addEventListener("click") do(event: Event):
        b.data.times = b.data.times + 1
        console.log("button clicked", b.data.times)
        b.update(b.data)
