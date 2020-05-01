import sequtils
import ./dom

type
  ProcRefresh*[D]  = proc(node: dom.Node, data: D)
  ProcGetValue*[D] = proc(data: D): D

  MatchConfig[D] = ref object
    selector: string
    refresh: seq[ProcRefresh[D]]
    fetchData: ProcGetValue[D]
    matches: seq[MatchConfig[D]]
    iter: bool

  Config*[D] = ref object
    matches: seq[MatchConfig[D]]

  CompMatchItem[D] = ref object
    node: dom.Node
    matches: seq[CompMatch[D]]

  CompMatch[D] = ref object
    refresh: seq[ProcRefresh[D]]
    fetchData: ProcGetValue[D]
    node: dom.Node
    oldValue: D
    case iter:bool
    of false:
      matches: seq[CompMatch[D]]
    of true:
      match_templates: seq[MatchConfig[D]]
      items: seq[CompMatchItem[D]]
      anchor: dom.Node

  Component*[D] = ref object
    matches: seq[CompMatch[D]]
    node: dom.Node

proc create*[D](): Config[D] =
  return new(Config[D])

proc create*[D](d: typedesc[D], configurator: proc(c: Config[D])): Config[D] =
  result = new(Config[D])
  configurator(result)

proc match*[D](t: Config[D] | MatchConfig[D], selector: string, fetchData: ProcGetValue[D], refresh: ProcRefresh[D]) =
  let match = MatchConfig[t.D](
    selector: selector,
    refresh: @[refresh],
    iter: false,
    fetchData: fetchData)
  t.matches.add(match)

proc iter*[D](t: Config[D] | MatchConfig[D], selector: string, fetchData: ProcGetValue[D], actions: proc(x: MatchConfig[D]) = nil): MatchConfig[D] {.discardable.} =
  let match = MatchConfig[t.D](
    selector: selector,
    refresh: @[],
    fetchData: fetchData,
    iter: true,
    matches: @[])
  t.matches.add(match)
  if actions != nil:
    actions(match)
  return match

proc compile[D](m0: MatchConfig[D], node: dom.Node): CompMatch[D] =
  let matched_node = node.querySelector(m0.selector)
  var match = CompMatch[D](
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

proc compile[D](tfs: seq[MatchConfig[D]], node: dom.Node): seq[CompMatch[D]] =
  result = @[]
  for tf in tfs:
    result.add(compile(tf, node))

proc compile*[D](tf: Config[D], node: dom.Node): Component[D] =
  var t = new(Component[D])
  t.matches = @[]
  t.node = node.cloneNode(true)
  for matchTmpl in tf.matches:
    var match = compile(matchTmpl, t.node)
    t.matches.add(match)
  return t

proc createIterItem[D](match: CompMatch[D], parentNode: dom.Node): CompMatchItem[D] =
  var node = match.node.cloneNode(true)
  result = CompMatchItem[D](
    node: node,
    matches: compile(match.match_templates, node))
  parentNode.insertBefore(node, match.anchor)

proc detach[D](iter_item: CompMatchItem[D], parentNode: dom.Node) =
  parentNode.removeChild(iter_item.node)

proc update*[D](match: CompMatch[D], data: D, refresh: bool = false) =
  mixin get, `==`, items
  let val = match.fetchData(data)
  if not refresh and val == match.oldValue:
    return

  match.oldValue = val
  if match.iter:
    var i = 0
    let parentNode = match.anchor.parentNode
    for item in items(val):
      var iter_item: CompMatchItem[D]

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

proc update*[D](t: Component[D], data: D, refresh: bool = false) =
  mixin get, `==`, items
  for match in t.matches:
    update(match, data, refresh)

proc attach*[D](t: Component[D], target, anchor: dom.Node, data: D) =
  t.update(data, refresh = true)
  target.insertBefore(t.node, anchor)

proc detach*(t: Component) =
  t.node.parentNode.removeChild(t.node)

#func get*[D,K](keys: varargs[K]): ProcGetValue[D] =
#  mixin `[]`
#  return proc(node: D): D =
#    result = node
#    for key in items(keys):
#      result = result[key]
#func get*[D,K](key: K): ProcGetValue[D] =
#  mixin `[]`
#  return proc(node: D): D =
#    return node[key]

