import ../svelte
import ../sveltejson
import ../dom
import json
import ./sample1

var config2* = create(JsonNode) do(t: auto):
  t.match("div.insert", get()) do(t: auto):
    # will insertBefore/attach(node, nil) the template tmpl1.clone()
    # and will continue refreshing it
    t.mount(tmpl1)

var node = document.querySelector("template#sample-2")
var tmpl2* = config2.compile(node.content)

if isMainModule:
  tmpl2.attach(node.parentNode, node, %*{"name": "Sample-2", "names": []})
