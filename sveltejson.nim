import ./svelte
import json

func get*(keys: varargs[string]): ProcGetValue[JsonNode] =
  return svelte.get(JsonNode, keys)

