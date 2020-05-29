import jsconsole

import ../../src/nclearseam
import ../../src/nclearseam/util
import ../../src/nclearseam/fetchutil
import ../../src/nclearseam/dom
import ../../src/nclearseam/registry

type
  ButtonTimes* = ref object
    count*: int
  ButtonData* = ref object
    times*: ButtonTimes

var Button*: Component[ButtonData]

components.declare(Button, fetchTemplate("button.html", "template", css = true)) do(node: dom.Node) -> Component[ButtonData]:
  return compile(ButtonData, node) do(b: auto):
    b.match(".times", ButtonData->times->count, eql).refresh(setText(int))
    #b.match(".times", b.get(times, count), eql).refresh(setText(int))
    b.match("button").addEventListener("click") do(event: Event):
        b.data.times.count = b.data.times.count + 1
        console.log("button clicked", b.data.times.count)
        b.update(b.data)
