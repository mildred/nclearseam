import ./svelte
import ./dom
import jsconsole
import json

func get(): ProcGetValue[JsonNode] =
  return proc(node: JsonNode): JsonNode = node
func get(k1: string): ProcGetValue[JsonNode] =
  return proc(node: JsonNode): JsonNode = node[k1]
func get(k1, k2: string): ProcGetValue[JsonNode] =
  return proc(node: JsonNode): JsonNode = node[k1][k2]

var testTemplate = create(JsonNode) do(t: auto):
  t.match("h1 .name", get "name") do(node: dom.Node, data: JsonNode):
    node.textContent = data.getStr()
  t.iter("ul li", get "names") do(name: auto):
    name.match(".name", get()) do(node: dom.Node, data: JsonNode):
      node.textContent = $data

proc mainTest*(node: dom.Node) {.exportc.} =
  var tmpl = testTemplate.compile(node)
  console.log("mainTest", tmpl)
  tmpl.attach(document.body, nil, %*{"name": "Name!!!", "names": ["a", "b"]})
  discard setTimeout(proc() =
    tmpl.update(%*{"name": "timeout", "names": ["a", "b", "c", "d"]})
  , 1000)


