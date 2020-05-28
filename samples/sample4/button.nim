import jsconsole

import ../../src/nclearseam
import ../../src/nclearseam/util
import ../../src/nclearseam/fetchutil
import ../../src/nclearseam/dom
import ../../src/nclearseam/registry

type ButtonData* = ref object
  times*: int

proc times(d: ButtonData): string = $d.times

var Button*: Component[ButtonData]

components.declare(Button, fetchTemplate("button.html", "template", css = true)) do(node: dom.Node) -> Component[ButtonData]:
  return compile(ButtonData, node) do(b: auto):
    b.match(".times", times, eql).refresh(setText)
    b.match("button").addEventListener("click") do(event: Event):
        b.data.times = b.data.times + 1
        console.log("button clicked", b.data.times)
        b.update(b.data)
