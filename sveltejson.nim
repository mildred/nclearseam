import ./svelte
import json

func get*(): ProcGetValue[JsonNode] =
  return proc(node: JsonNode): JsonNode = node
func get*(k1: string): ProcGetValue[JsonNode] =
  return proc(node: JsonNode): JsonNode = node[k1]
func get*(k1, k2: string): ProcGetValue[JsonNode] =
  return proc(node: JsonNode): JsonNode = node[k1][k2]

