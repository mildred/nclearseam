import ../svelte
import ../dom
import json
import sequtils

type
  Comp2Item = ref object
    name: string
    children: seq[Comp2Data]
  Comp2Data = ref object
    names: seq[Comp2Item]
var Comp2: Component[Comp2Data]

proc iterNames(c2: Comp2Data): ProcIter[Comp2Item] =
  seqIterator(c2.names)

proc iterChildren(c2: Comp2Item): ProcIter[Comp2Data] =
  seqIterator(c2.children)

type Comp1Data = ref object
  name: string
  comp2: Comp2Data
var Comp1: Component[Comp1Data]

proc toComp2(d: Comp1Data): Comp2Data =
  d.comp2

Comp2 = compile(Comp2Data, document.querySelector("template#comp2").content) do (t: auto):
  t.iter("ul li", iterNames) do(name: auto):
    name.match(".name") do(node: dom.Node, data: Comp2Item):
      node.textContent = data.name
    name.iter(".child", iterChildren) do(child: auto):
      child.mount(late(proc(): Component[Comp2Data] = Comp2))

Comp1 = compile(Comp1Data, document.querySelector("template#comp1").content) do (t: auto):
  t.match("h1 .name") do(node: dom.Node, data: Comp1Data):
    node.textContent = data.name
  t.match("div.insert") do(t: auto):
    t.mount(Comp2, toComp2)

if isMainModule:
  Comp1.clone().attach(document.body, nil, Comp1Data(
      name: "Hello comp1",
      comp2: Comp2Data(
        names: @[
          Comp2Item(name: "brian", children: @[Comp2Data(names: @[
            Comp2Item(name: "arthur", children: @[]),
          ])]),
          Comp2Item(name: "zoe", children: @[]),
          Comp2Item(name: "ashley", children: @[]),
        ],
      )
    ))
