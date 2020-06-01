import jsconsole
import asyncjs

import nclearseam
import nclearseam/dom
import nclearseam/registry

import ./app

proc main() {.async discardable.} =
  await components.init()
  App.clone().attach(document.body, nil, AppData())

when isMainModule:
  main()
