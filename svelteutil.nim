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
