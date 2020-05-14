import ./svelte
import ./dom
import ./sveltejson
import json
import sugar

proc bindValue*(node: dom.Node, data: JsonNode) =
  node.value = $data
  capture data:
    node.onchange = proc(e: Event) =
      #data = %*e.target.value
      e.target.value = $data

proc setText*(node: dom.Node, data: JsonNode) =
  node.textContent = $data

func get*[K,D](typ: typedesc[D], keys: varargs[K]): ProcGetValue[D] =
  mixin `[]`
  let keys = @keys
  return proc(node: D): D =
    result = node
    for key in items(keys): result = result[key]
