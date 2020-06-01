import jsconsole
import jsffi
import json

import nclearseam
import nclearseam/util
import nclearseam/fetchutil
import nclearseam/dom
import nclearseam/registry

import ./settings

var window {.importc, nodecl.}: JsObject

type
  AppData* = ref object
    times*: int
    doc: DocData

  DocData = ref object
    children: seq[JsonNode]
    settings: Settings

var App*: Component[AppData]

proc open(c: Component[AppData]) =
  let input = document.createElement("input")
  input.style.display = "none";
  input.setAttribute("type", "file")
  input.addEventListener("change", proc(e: Event) =
    let file = input.toJs.files[0]
    if file == nil: return

    let reader = jsNew window.FileReader()
    reader.onload = (proc() =
      let json = reader.result.to(cstring)
      c.data.doc = parseJSON($json).to(DocData)
      c.update(c.data, nil, refreshAll)
    )

    reader.readAsText(file)
  )
  document.body.appendChild(input);
  input.click();
  document.body.removeChild(input);

components.declare(App, fetchTemplate("app.html", "template", css = true)) do(node: dom.Node) -> Component[AppData]:
  return compile(AppData, node) do(c: auto):
    c.match(".times", c.get(times), eql).refresh(setText(int))
    c.match("button.ouvrir").addEventListener("click") do(event: Event):
      open(c)
    c.match("button.click").addEventListener("click") do(event: Event):
      c.data.times = c.data.times + 1
      console.log("button clicked", c.data.times)
      c.update(c.data)
    c.match(".num-children", c.get(doc, children, len), eql).refresh(setText(int))
    c.match(".settings") do(s: auto):
      s.mount(SettingsComponent, s.access->doc->settings)
