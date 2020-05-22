import ../svelte
import ../sveltejson
import ../dom
import json
import jsconsole

var config1* = create(JsonNode) do(t: auto):
  t.match("h1 .name", get "name").refresh do(node: dom.Node, data: JsonNode):
    node.textContent = data.getStr()
  t.iter("ul li", jsonIter "names") do(name: auto):
    name.match(".name").refresh do(node: dom.Node, data: JsonNode):
      node.textContent = $data

var node = document.querySelector("template#sample-1")
var tmpl1* = config1.compile(node.content)

if isMainModule:
  console.log(node)
  console.log(tmpl1)
  tmpl1.attach(node.parentNode, node, %*{"name": "Name!!!", "names": ["a", "b"]})
  discard setTimeout(proc() =
    tmpl1.update(%*{"name": "timeout", "names": ["a", "b", "c", "d"]})
  , 1000)
