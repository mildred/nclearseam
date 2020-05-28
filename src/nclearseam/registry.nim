import sequtils
import asyncjs
import jsffi
import ./dom

import ../nclearseam

var Promise {.importc, nodecl.}: JsObject

type
  ProcInit = proc(): Future[void]
  ProcCreator*[T] = proc(node: dom.Node): Component[T]
  Registry = tuple
    initProcs: seq[ProcInit]

var components*: Registry

proc initComp[T](component: var Component[T], node: Future[dom.Node], creator: ProcCreator[T]): Future[void] {.async.} =
  let n = await node
  component = creator(n)

proc declare*[T](registry: var Registry, component: var Component[T], node: Future[dom.Node], creator: ProcCreator[T]) =
  registry.initProcs.add(proc(): Future[void] = initComp[T](component, node, creator))

proc init*(registry: Registry): Future[void] {.async.} =
  await Promise.all(registry.initProcs.map(proc(p: ProcInit): Future[void] = p())).to(Future[void])
