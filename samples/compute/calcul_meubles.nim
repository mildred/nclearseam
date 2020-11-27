import jsconsole
import asyncjs
import dom

import nclearseam
import nclearseam/extradom
import nclearseam/registry

import ./app
import ./settings

proc main() {.async discardable.} =
  await components.init()
  App.clone().attach(document.body, nil, AppData())

when isMainModule:
  main()
