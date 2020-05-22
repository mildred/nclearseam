import ./svelte
import ./dom

func get*[K,D](typ: typedesc[D], keys: varargs[K]): ProcTypeConverter[D,D] =
  mixin `[]`
  let keys = @keys
  return proc(node: D): D =
    result = node
    for key in items(keys): result = result[key]

#
# Helper procedures to create iterator functions
#

proc seqIterator*[D](arr: seq[D]): ProcIter[D] =
  #mixin items
  #var it = items # Instanciate iterator
  var it = 0
  var empty: D

  proc next(): tuple[ok: bool, data: D] =
    #let item: D = it(data)
    #if finished(it): return (false, item)
    #else: return (true, data)
    if it >= len(arr): return (false, empty)
    result = (true, arr[it])
    it = it + 1

  return next

proc dataIterator[D](data: D): ProcIter[D] =
  mixin items
  var arr: seq[D] = @[]
  for item in items(data):
    arr.add(item)
  return seqIterator[D](arr)

