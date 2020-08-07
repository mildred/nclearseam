import dom
import jsffi

proc ownerDocument*(n: Node): Document =
  toJs(n).ownerDocument.to(Document)

{.push importcpp.}

proc querySelector*(d: Node, selectors: cstring): seq[Element]
proc querySelectorAll*(d: Node, selectors: cstring): seq[Element]

proc createComment*(d: Document, data: cstring): Node {.importcpp.}

{.pop.}
