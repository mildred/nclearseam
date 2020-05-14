import ../svelte
import ../dom
import json
import ./sample1
import sequtils

type Comp2Data = ref object
  names: seq[string]
var Comp2: Component[Comp2Data]

#proc iterNames(c2: Comp2Data): auto =
#  items(c2.names)

type Comp1Data = ref object
  name: string
  comp2: Comp2Data
var Comp1: Component[Comp1Data]

proc toComp2(d: Comp1Data): Comp2Data =
  d.comp2

Comp1 = compile(Comp1Data, document.querySelector("template#comp1")) do (t: auto):
  t.match("h1 .name") do(node: dom.Node, data: Comp1Data):
    node.textContent = data.name
  t.match("div.insert") do(t: auto):
    t.mount(Comp2, toComp2)

Comp2 = compile(Comp2Data, document.querySelector("template#comp2")) do (t: auto):
  t.iter("ul li") do(name: auto):
    name.match(".name") do(node: dom.Node, data: Comp2Data):
      node.textContent = data.names[0]

if isMainModule:
  Comp1.clone().attach(node.parentNode, node, %*{"name": "Sample-2", "names": []})
