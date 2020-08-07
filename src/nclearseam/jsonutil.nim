import ./util
import ../nclearseam
import dom
import json
import sugar

func get*(keys: varargs[string]): ProcTypeConverter[JsonNode,JsonNode] =
  return util.get(JsonNode, keys)

func jsonIter*(keys: varargs[string]): ProcIterator[JsonNode,JsonNode] =
  let keys = @keys # convert to seq
  return proc(n: JsonNode): ProcIter[JsonNode] =
    var empty :JsonNode
    var it = 0
    var data = n
    for key in items(keys): data = data[key]

    return proc(): tuple[ok: bool, data: JsonNode] =
      if it >= len(data): return (false, empty)
      result = (true, data[it])
      it = it + 1

proc bindValue*(node: dom.Node, data: JsonNode) =
  node.value = $data
  capture data:
    const change = proc(event: Event) =
      #data = %*e.target.value
      event.target.value = $data
    addEventListener(node, "change", change)

proc setText*(node: dom.Node, data: JsonNode) =
  node.textContent = $data

