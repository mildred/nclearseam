import random
import strformat
import strutils
import asyncjs
import jsffi
import dom
import ./extradom

var rand = initRand(1)

proc scope*(node: dom.Node) =
  let comp = toHex(next(rand))
  for element in node.toJs.querySelectorAll("*"):
    element.classList.add(&"component-{comp}")
  for style in node.querySelectorAll("style[scope]"):
    let scope = toHex(next(rand))
    style.parentNode.toJs.classList.add(&"scope-{scope}")
    # TODO: do some basic CSS parsing at least to avoid replacing comments or
    # strings
    style.textContent = ($style.textContent)
      .replace(":scope", &".scope-{scope}")
      .replace(":component", &".component-{comp}")

proc css*(futureNode: Future[dom.Node]): Future[dom.Node] {.async.} =
  let node = await futureNode
  let res = node.cloneNode(true)
  scope(res)
  return res

