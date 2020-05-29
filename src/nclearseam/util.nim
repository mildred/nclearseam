import macros

import ../nclearseam
import ./dom
#import typeinfo

proc `|`*[T1,T2,T3] (p1: proc(x: T1): T2, p2: proc(x: T2): T3): proc(x: T1): T3 =
  ## Return a proc that is the equivalent of piping the two input proc together
  result = proc(x: T1): T3 = x.p1().p2()

#func get*[K,D](typ: typedesc[D], keys: varargs[K]): ProcTypeConverter[D,D] =
#  mixin `[]`
#  let keys = @keys
#  return proc(node: D): D =
#    result = node
#    for key in items(keys): result = result[key]

macro get_fields_macro(t: untyped, args: varargs[untyped]): untyped =

  # Return type goes first, then all the arguments
  var dotExpr: NimNode = ident("arg0")
  var statements: NimNode = newStmtList()

  for i in 0 .. args.len-1:
    dotExpr = newDotExpr(dotExpr, args[i])
    let dot = newDotExpr(ident("arg" & $i), args[i])
    let ifexpr = newNimNode(nnkIfExpr)
      .add(newNimNode(nnkElifExpr)
        .add(newCall(bindSym"isNil", dot))
        .add(newCall(bindSym"new", newNimNode(nnkTypeOfExpr).add(dot))))
      .add(newNimNode(nnkElseExpr)
        .add(dot))
    statements.add(newLetStmt(ident("arg" & $(i+1)), ifexpr))

  statements.add(newNimNode(nnkReturnStmt).add(ident("arg" & $(args.len))))

  var params: seq[NimNode] = @[
    newIdentNode("auto"),           # return type
    newIdentDefs(ident("arg0"), t), # argument
  ]

  result = newProc(procType = nnkLambda, params = params, body = dotExpr)

template get*[X,D](c: MatchConfig[X,D], args: varargs[untyped]): auto =
  get_fields_macro(c.D, args)

template get*[D](c: Config[D], args: varargs[untyped]): auto =
  get_fields_macro(c.D, args)

template get_fields*(t: typedesc, args: varargs[untyped]): auto =
  get_fields_macro(t, args)

template `->`*(t: typedesc, ident: untyped): auto =
  get_fields_macro(t, ident)

template `->`*[T1,T2](left: proc (arg0: T1): T2, ident: untyped): auto =
  left | get_fields_macro(T2, ident)

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

proc setText*[T](typ: typedesc[T]): proc(node: dom.Node, text: T) =
  result = (proc(node: dom.Node, text: T) = node.textContent = $text)

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

