import ./button
import ../../src/nclearseam
import ../../src/nclearseam/dom

var Button = compileButton(document.querySelector("template#button").content)

if isMainModule:
  Button.clone().attach(document.body, nil, ButtonData())
