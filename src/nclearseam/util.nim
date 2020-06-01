import macros
#import jsconsole
import jsffi

import ../nclearseam
import ./dom
#import typeinfo

proc eql*[T](s1, s2: T): bool =
  mixin `==`
  result = (s1 == s2)

proc `|`*[T1,T2,T3] (p1: proc(x: T1): T2, p2: proc(x: T2): T3): proc(x: T1): T3 =
  ## Return a proc that is the equivalent of piping the two input proc together
  result = proc(x: T1): T3 = x.p1().p2()

#func get*[K,D](typ: typedesc[D], keys: varargs[K]): ProcTypeConverter[D,D] =
#  mixin `[]`
#  let keys = @keys
#  return proc(node: D): D =
#    result = node
#    for key in items(keys): result = result[key]

macro get_fields_type_macro(t: untyped, args: varargs[untyped]): untyped =
  var expr = nnkCall.newTree(bindSym"default", nnkBracketExpr.newTree(ident("typedesc"), t))
  for i in 0 .. args.len-1:
    expr = newDotExpr(expr, args[i])
  result = nnkCall.newTree(bindSym"typeof", expr)

macro get_fields_macro(t: untyped, args: varargs[untyped]): untyped =

  # Return type goes first, then all the arguments
  var statements: NimNode = newStmtList()


  for i in 0 .. args.len-1:
    #dumpAstGen:
    #  var arg1 = arg0.argsi
    #  when compiles(arg1 == nil):
    #    if arg1 == nil:
    #      arg1 = new(typeof(arg1))
    let dot = newDotExpr(ident("arg" & $i), args[i])
    let arg1 = ident("arg" & $(i+1))
    statements.add(
      nnkVarSection.newTree(
        nnkIdentDefs.newTree(arg1, newEmptyNode(), dot)
      ),
      nnkWhenStmt.newTree(
        nnkElifBranch.newTree(
          newCall(bindSym"compiles", newCall(bindSym"isNil", arg1)),
          nnkStmtList.newTree(
            nnkIfStmt.newTree(
              nnkElifBranch.newTree(
                newCall(bindSym"isNil", arg1),
                nnkStmtList.newTree(
                  nnkAsgn.newTree(arg1, newCall(bindSym"new", nnkTypeOfExpr.newTree(arg1)))
                )
              )
            )
          )
        )
      )
    )

  statements.add(newNimNode(nnkReturnStmt).add(ident("arg" & $(args.len))))

  var returnType = nnkCall.newTree(bindSym"default", nnkBracketExpr.newTree(ident("typedesc"), t))
  for i in 0 .. args.len-1:
    returnType = newDotExpr(returnType, args[i])
  returnType = nnkCall.newTree(bindSym"typeof", returnType)

  var params: seq[NimNode] = @[
    returnType,                     # return type
    newIdentDefs(ident("arg0"), t), # argument
  ]

  result = newProc(procType = nnkLambda, params = params, body = statements)

macro set_fields_macro(t: untyped, args: varargs[untyped]): untyped =

  # Return type goes first, then all the arguments
  var statements: NimNode = newStmtList()


  for i in 0 .. args.len-1:
    #dumpAstGen:
    #  var arg1 = arg0.argsi
    #  when compiles(arg1 == nil):
    #    if arg1 == nil:
    #      arg1 = new(typeof(arg1))
    let dot = newDotExpr(ident("arg" & $i), args[i])
    let arg1 = ident("arg" & $(i+1))
    statements.add(
      nnkVarSection.newTree(
        nnkIdentDefs.newTree(arg1, newEmptyNode(), dot)
      ),
      nnkWhenStmt.newTree(
        nnkElifBranch.newTree(
          newCall(bindSym"compiles", newCall(bindSym"isNil", arg1)),
          nnkStmtList.newTree(
            nnkIfStmt.newTree(
              nnkElifBranch.newTree(
                newCall(bindSym"isNil", arg1),
                nnkStmtList.newTree(
                  nnkAsgn.newTree(arg1, newCall(bindSym"new", nnkTypeOfExpr.newTree(arg1)))
                )
              )
            )
          )
        )
      )
    )

  #dumpAstGen:
  #  arg1 = value
  statements.add(
    nnkStmtList.newTree(
      nnkAsgn.newTree(ident("arg" & $(args.len)), ident("value"))
    )
  )

  var i = args.len
  while i > 0:
    i = i - 1
    #dumpAstGen:
    #  arg0.argsi = arg1
    let dot = newDotExpr(ident("arg" & $i), args[i])
    statements.add(
      nnkStmtList.newTree(
        nnkAsgn.newTree(dot, ident("arg" & $(i+1)))
      )
    )

  var returnType = nnkCall.newTree(bindSym"default", nnkBracketExpr.newTree(ident("typedesc"), t))
  for i in 0 .. args.len-1:
    returnType = newDotExpr(returnType, args[i])
  returnType = nnkCall.newTree(bindSym"typeof", returnType)

  var params: seq[NimNode] = @[
    newIdentNode("void"),                     # return type
    newIdentDefs(ident("arg0"), t),           # argument
    newIdentDefs(ident("value"), returnType), # argument
  ]

  result = newProc(procType = nnkLambda, params = params, body = statements)

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

proc combine_set_fields[D1,D2,D3](
    get1: proc(data: D1): D2,
    set1: proc(data: var D1, value: D2),
    set2: proc(data: var D2, value: D3)): proc(data: var D1, value: D3) =
  return (proc(data: var D1, val3: D3) =
    let val2 = get1(data)
    set2(val2, val3)
    set1(data, val2))

# Workaround https://github.com/nim-lang/Nim/issues/14534
proc paren[T](x: T): T {.importcpp: "(#)", nodecl.}

template `->`*[T1,T2](left: TypeSelector[T1,T2], ident: untyped): auto =
  paren(TypeSelector[T1, get_fields_type_macro(T2, ident)](
    get: left.get | get_fields_macro(T2, ident),
    set: proc(data: var T1, val3: get_fields_type_macro(T2, ident)) =
      let val2 = left.get(data)
      let set2 = set_fields_macro(T2, ident)
      set2(val2, val3)
      left.set(data, val2),
    id:  left.id & @[astToStr(ident)]
  ))

proc access*[D](c: Config[D]): TypeSelector[D,D] =
  result = TypeSelector[D,D](
    get: proc(data: D): D = data,
    set: proc(data: var D, value: D) = data = value,
    id:  @[]
  )

proc access*[X,D](c: MatchConfig[X,D]): TypeSelector[D,D] =
  result = TypeSelector[D,D](
    get: proc(data: D): D = data,
    set: proc(data: var D, value: D) = data = value,
    id:  @[]
  )

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

proc setValue*[T](typ: typedesc[T]): proc(node: dom.Node, value: T) =
  return proc(node: dom.Node, value: T) =
    node.toJs.value = value

proc bindValue*[T](typ: typedesc[T]): ProcRefresh[T] =
  return proc(re: RefreshEvent[T]) =
    #console.log("bindValue(%o)", re)
    if re.init:
      assert(re.set != nil, "Cannot bind value where type selector does not allow changing the data")
      re.node.addEventListener("change") do(e: dom.Event):
        re.set(re.node.toJs["value"].to(T))
    re.node.toJs.value = re.data.toJs

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

