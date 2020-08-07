import sequtils
import asyncjs
import jsffi
import dom

import ../nclearseam

var Promise {.importc, nodecl.}: JsObject

type
  ProcInit = proc(): Future[void]
  ProcCreator*[T] = proc(node: dom.Node): Component[T]
  Registry = tuple
    initProcs: seq[ProcInit]

var components*: Registry

proc initComp[T](set_component: proc(c: Component[T]), node: Future[dom.Node], creator: ProcCreator[T]): Future[void] {.async.} =
  #component = Component[T]()
  let n = await node
  #component[] = creator(n)[]
  set_component(creator(n))

proc declare*[T](registry: var Registry, component: var Component[T], node: Future[dom.Node], creator: ProcCreator[T]) =
  let set_component = proc(c: Component[T]) = component = c
  registry.initProcs.add(proc(): Future[void] = initComp[T](set_component, node, creator))

proc declare*[T](registry: var Registry, component: var ComponentInterface[T], node: Future[dom.Node], creator: ProcCreator[T]) =
  var comp: Component[T] = nil
  let set_component = proc(c: Component[T]) = comp = c
  component = late(proc(): Component[T] = comp)
  registry.initProcs.add(proc(): Future[void] = initComp[T](set_component, node, creator))

proc compile*[T](registry: var Registry, component: var ComponentInterface[T], node: Future[dom.Node], configurator: ProcMatchConfig[T,T], equal: proc(v1, v2: T): bool = nil) =
  registry.declare(component, node) do(node: dom.Node) -> Component[T]:
    return compile(T, node, configurator, equal)

proc init*(registry: Registry): Future[void] {.async.} =
  await Promise.all(registry.initProcs.map(proc(p: ProcInit): Future[void] = p())).to(Future[void])
