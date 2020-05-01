import macros
import json
import sequtils
import ./dom

#type
#  Template* = object
#  #  matches: seq[TemplateMatch]
#  TemplateFactory* = proc(node: dom.Node): Template
#
#template svelte*(rootNode: untyped, data: untyped, actions: untyped): TemplateFactory =
#  (proc(rootNode: dom.Node): Template =
#    var t = Template(matches: [])
#  )
#
#proc update(t: ref Template, data: JsonNode) =
#  discard

type
  TmplRefreshProc*[Dval] = proc(node: dom.Node, data: Dval)
  TmplGetValueProc*[D,Dval] = proc(data: D): Dval
  TmplMatchFactory[D,Dval] = ref object
    selector: string
    refresh: seq[TmplRefreshProc[D]]
    fetchData: TmplGetValueProc[D,Dval]
    matches: seq[TmplMatchFactory[Dval,Dval]]
    iter: bool
  TmplMatchItem[D,Dval] = ref object
    node: dom.Node
    matches: seq[TmplMatch[D,Dval]]
  TmplMatch[D,Dval] = ref object
    refresh: seq[TmplRefreshProc[D]]
    fetchData: TmplGetValueProc[D,Dval]
    node: dom.Node
    oldValue: DVal
    case iter:bool
    of false:
      matches: seq[TmplMatch[Dval,Dval]]
    of true:
      match_templates: seq[TmplMatchFactory[Dval,Dval]]
      items: seq[TmplMatchItem[Dval,Dval]]
      anchor: dom.Node
  Tmpl*[D,Dval] = ref object
    matches: seq[TmplMatch[D,Dval]]
    node: dom.Node
  TmplFactory*[D,Dval] = ref object
    matches: seq[TmplMatchFactory[D,Dval]]

proc create*[D,Dval](): TmplFactory[D,Dval] =
  return new(TmplFactory[D,Dval])

proc match*[D,Dval](t: TmplFactory[D,Dval] | TmplMatchFactory[D,Dval], selector: string, fetchData: TmplGetValueProc[D,Dval], refresh: TmplRefreshProc[D]) =
  let match = TmplMatchFactory[t.D, t.Dval](
    selector: selector,
    refresh: @[refresh],
    iter: false,
    fetchData: fetchData)
  t.matches.add(match)

proc iter*[D, Dval](t: TmplFactory[D,Dval] | TmplMatchFactory[D,Dval], selector: string, fetchData: TmplGetValueProc[D,Dval], actions: proc(x: TmplMatchFactory[D,Dval]) = nil): TmplMatchFactory[D,Dval] {.discardable.} =
  let match = TmplMatchFactory[t.D, t.Dval](
    selector: selector,
    refresh: @[],
    fetchData: fetchData,
    iter: true,
    matches: @[])
  t.matches.add(match)
  if actions != nil:
    actions(match)
  return match

proc compile[D,Dval](m0: TmplMatchFactory[D,Dval], node: dom.Node): TmplMatch[D,Dval] =
  let matched_node = node.querySelector(m0.selector)
  var match = TmplMatch[D,Dval](
    refresh: m0.refresh,
    fetchData: m0.fetchData,
    iter: m0.iter,
    node: matched_node)
  match.node = matched_node
  if match.iter:
    match.anchor = matched_node.ownerDocument.createComment(matched_node.outerHTML)
    match.match_templates = m0.matches
    match.items = @[]
    matched_node.parentNode.replaceChild(match.anchor, matched_node)
  else:
    match.matches = @[]
    for submatch in m0.matches:
      match.matches.add(submatch.compile(matched_node))
  return match

proc compile*[D,Dval](tfs: seq[TmplMatchFactory[D,Dval]], node: dom.Node): seq[TmplMatch[D,Dval]] =
  result = @[]
  for tf in tfs:
    result.add(compile(tf, node))

proc compile*[D,Dval](tf: TmplFactory[D,Dval], node: dom.Node): Tmpl[D,Dval] =
  var t = new(Tmpl[D,Dval])
  t.matches = @[]
  t.node = node.cloneNode(true)
  for matchTmpl in tf.matches:
    var match = compile(matchTmpl, t.node)
    t.matches.add(match)
  return t

proc createIterItem[D,Dval](match: TmplMatch[D,Dval], parentNode: dom.Node): TmplMatchItem[Dval,Dval] =
  var node = match.node.cloneNode(true)
  result = TmplMatchItem[Dval,Dval](
    node: node,
    matches: compile(match.match_templates, node))
  parentNode.insertBefore(node, match.anchor)

proc detach[D,Dval](iter_item: TmplMatchItem[D,Dval], parentNode: dom.Node) =
  parentNode.removeChild(iter_item.node)

proc update*[D,Dval](match: TmplMatch[D,Dval], data: D, refresh: bool = false) =
  mixin get, `==`, items
  let val = match.fetchData(data)
  if not refresh and val == match.oldValue:
    return

  match.oldValue = val
  if match.iter:
    var i = 0
    let parentNode = match.anchor.parentNode
    for item in items(val):
      var iter_item: TmplMatchItem[Dval,Dval]

      # Create item if needed
      if i < len(match.items):
        iter_item = match.items[i]
      else:
        iter_item = createIterItem(match, parentNode)
        match.items.add(iter_item)

      # Refresh the node
      for refreshProc in match.refresh:
        refreshProc(iter_item.node, item)

      # Refresh the submatches
      for submatch in iter_item.matches:
        submatch.update(item, refresh)

      i = i + 1

    # Remove extra items if there is any because the list shrinked
    while i < len(match.items):
      detach(pop(match.items), parentNode)
  else:
    for refreshProc in match.refresh:
      refreshProc(match.node, val)
    for submatch in match.matches:
      discard

proc update*[D,Dval](t: Tmpl[D,Dval], data: D, refresh: bool = false) =
  mixin get, `==`, items
  for match in t.matches:
    update(match, data, refresh)

proc attach*[D,Dval](t: Tmpl[D,Dval], target, anchor: dom.Node, data: D) =
  t.update(data, refresh = true)
  target.insertBefore(t.node, anchor)

proc detach*(t: Tmpl) =
  t.node.parentNode.removeChild(t.node)

#func get*[D,K](keys: varargs[K]): TmplGetValueProc[D,D] =
#  mixin `[]`
#  return proc(node: D): D =
#    result = node
#    for key in items(keys):
#      result = result[key]
#func get*[D,Dkey,Dval](key: Dkey): TmplGetValueProc[D,Dval] =
#  mixin `[]`
#  return proc(node: D): Dval =
#    return node[key]

template match0*(t: TmplFactory or TmplMatchFactory, selector, key, refresh: typed) =
  var fetcher: TmplGetValueProc[t.D, t.Dval]
  when key is TmplGetValueProc[t.D, t.Dval]:
    fetcher = key
  else:
    fetcher = get(key)

  t.match(selector, fetcher, refresh)

template match0*(t: TmplFactory or TmplMatchFactory, selector, key: typed, nodeArg, dataArg, actions: untyped) =
  var fetcher: TmplGetValueProc[t.D, t.Dval]
  when key is TmplGetValueProc[t.D, t.Dval]:
    fetcher = key
  else:
    fetcher = get(key)

  t.match0(selector, key) do(nodeArg: dom.Node, dataArg: t.Dval):
    actions

template iter0*[D,Dval](t: TmplFactory[D,Dval] or TmplMatch[D,Dval], selector: string, key: typed, iterArg, actions: untyped) =
  var fetcher: TmplGetValueProc[t.D, t.Dval]
  when key is TmplGetValueProc[t.D, t.Dval]:
    fetcher = key
  else:
    fetcher = get(key)

  block:
    var iterArg = t.add_match_iter(selector, fetcher)
    actions

template iter1*[D,Dval](t: TmplFactory[D,Dval] or TmplMatch[D,Dval], selector: string, key: typed, actions: proc(x: TmplFactory[D,Dval])) =
  var fetcher: TmplGetValueProc[t.D, t.Dval]
  when key is TmplGetValueProc[t.D, t.Dval]:
    fetcher = key
  else:
    fetcher = get(key)

  actions(t.add_match_iter(selector, fetcher))

template update*(t: TmplMatch, nodeArg, dataArg, actions: untyped) =
  t.matches.add(proc(nodeArg: dom.Node, dataArg: t.Dval) =
    actions
  )

