import ./button
import ../../dom
import ../../svelte

var Button = compileButton(document.querySelector("template#button").content)

if isMainModule:
  Button.clone().attach(document.body, nil, ButtonData())
