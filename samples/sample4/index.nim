import asyncjs

import ../../src/nclearseam
import ../../src/nclearseam/dom
import ../../src/nclearseam/registry

import ./button

proc main() {.async discardable.} =
  await components.init()
  Button.clone().attach(document.body, nil, ButtonData())

when isMainModule:
  main()
