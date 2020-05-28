import asyncjs
import jsffi
import ./dom
import ./css

var window {.importc, nodecl.}: JsObject

proc fetchTemplate*(relPath: string): Future[dom.Node] {.async.} =
  let response = await window.fetch(relpath).to(Future[JsObject])
  let text = await response.text().to(Future[JsObject])
  return window.document.createRange().createContextualFragment(text).to(dom.Node)

proc fetchTemplate*(relPath, templateSelector: string, css: bool = false): Future[dom.Node] {.async.} =
  let tmpl = await fetchTemplate(relPath)
  let node = tmpl.querySelector(templateSelector).content
  if css:
    scope(node)
  return node
