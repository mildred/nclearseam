import ./nim_svelte
import ./dom
import jsconsole
import json

func get(): TmplGetValueProc[JsonNode,JsonNode] =
  return proc(node: JsonNode): JsonNode = node
func get(k1: string): TmplGetValueProc[JsonNode,JsonNode] =
  return proc(node: JsonNode): JsonNode = node[k1]
func get(k1, k2: string): TmplGetValueProc[JsonNode,JsonNode] =
  return proc(node: JsonNode): JsonNode = node[k1][k2]

var testTemplate = create[JsonNode,JsonNode]()
testTemplate.match("h1 .name", get "name") do(node: dom.Node, data: JsonNode):
  node.textContent = data.getStr()
testTemplate.iter("ul li", get "names") do(name: auto):
  name.match(".name", get()) do(node: dom.Node, data: JsonNode):
    node.textContent = $data

proc mainTest*(node: dom.Node) {.exportc.} =
  var tmpl = testTemplate.compile(node)
  console.log("mainTest", tmpl)
  tmpl.attach(document.body, nil, %*{"name": "Name!!!", "names": ["a", "b"]})
  discard setTimeout(proc() =
    tmpl.update(%*{"name": "timeout", "names": ["a", "b", "c", "d"]})
  , 1000)

#template(rootNode, data):
#  match(rootNode, "h1 .name", span):
#    if data["nameChanged"]:
#      span.textContent = data["name"]
#  match_iterate(rootNode, "ul li", data["children"], li, child):
#    match(li, ".name", span):
#      if child["nameChanged"]:
#        span.textContent = child["name"]


