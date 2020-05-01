import ../svelte
import ../sveltejson
import ../dom
import json
import jsconsole

var testTemplate = create(JsonNode) do(t: auto):
  t.match("h1 .name", get "name") do(node: dom.Node, data: JsonNode):
    node.textContent = data.getStr()
  t.iter("ul li", get "names") do(name: auto):
    name.match(".name", get()) do(node: dom.Node, data: JsonNode):
      node.textContent = $data

var node = document.querySelector("template#sample-1")
console.log(node)
var tmpl = testTemplate.compile(node.content)
console.log(tmpl)
tmpl.attach(node.parentNode, node, %*{"name": "Name!!!", "names": ["a", "b"]})
discard setTimeout(proc() =
  tmpl.update(%*{"name": "timeout", "names": ["a", "b", "c", "d"]})
, 1000)
