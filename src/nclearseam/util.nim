import ../nclearseam
import ./dom
#import typeinfo

func get*[K,D](typ: typedesc[D], keys: varargs[K]): ProcTypeConverter[D,D] =
  mixin `[]`
  let keys = @keys
  return proc(node: D): D =
    result = node
    for key in items(keys): result = result[key]

#proc isRef[D](val: D): bool =
#  case kind(val)
#  of akRef: return true
#  of akPtr: return true
#  else: return false

proc changed*[D](val1, val2: D): bool =
  result = true
  # return if isRef(val1): true else: val1 != val2

#
# Config extensions
#

proc addEventListener*[X,D](c: MatchConfig[X,D], event: string, cb: proc(ev: Event), useCapture: bool = false) =
  ## Short for `c.init(proc(node: dom.Node) = node.addEventListener(ev, cb, useCapture))`
  c.init do(node: dom.Node):
    node.addEventListener(event, cb, useCapture)

proc addEventListener*[X,D](c: MatchConfig[X,D], event: string, cb: proc(ev: Event), options: dom.AddEventListenerOptions) =
  ## Short for `c.init(proc(node: dom.Node) = node.addEventListener(ev, cb, options))`
  c.init do(node: dom.Node):
    node.addEventListener(event, cb, options)

#
# DOM Utils
#

proc setText*(node: dom.Node, text: string) =
  node.textContent = text

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

proc dataIterator*[D](data: D): ProcIter[D] =
  mixin items
  var arr: seq[D] = @[]
  for item in items(data):
    arr.add(item)
  return seqIterator[D](arr)

