import sequtils
import strformat
import ./dom

type
  CompileError* = object of CatchableError

  ProcRefresh*[D]  = proc(node: dom.Node, data: D)
  ProcGetValue*[D] = proc(data: D): D

  MatchConfig*[D] = ref object
    selector: string
    refresh: seq[ProcRefresh[D]]
    fetchData: ProcGetValue[D]
    matches: seq[MatchConfig[D]]
    mount: Component[D]
    iter: bool

  Config*[D] = ref object
    matches: seq[MatchConfig[D]]

  CompMatchItem[D] = ref object
    node: dom.Node
    matches: seq[CompMatch[D]]
    mount: Component[D]

  CompMatch[D] = ref object
    refresh: seq[ProcRefresh[D]]
    fetchData: ProcGetValue[D]
    node: dom.Node
    oldValue: D
    case iter:bool
    of false:
      mount: Component[D]
      matches: seq[CompMatch[D]]
    of true:
      mount_template: Component[D]
      match_templates: seq[MatchConfig[D]]
      items: seq[CompMatchItem[D]]
      anchor: dom.Node

  Component*[D] = ref object
    config: Config[D]
    matches: seq[CompMatch[D]]
    node: dom.Node
    original_node: dom.Node

proc create*[D](): Config[D] =
  return new(Config[D])

proc create*[D](d: typedesc[D], configurator: proc(c: Config[D])): Config[D] =
  result = new(Config[D])
  configurator(result)

proc match*[D](t: Config[D] | MatchConfig[D], selector: string, fetchData: ProcGetValue[D], actions: proc(x: MatchConfig[D]) = nil): MatchConfig[D] {.discardable.} =
  result = MatchConfig[t.D](
    selector: selector,
    fetchData: fetchData,
    refresh: @[],
    mount: nil,
    iter: false)
  t.matches.add(result)
  if actions != nil:
    actions(result)

proc refresh*[D](t: MatchConfig[D], refresh: ProcRefresh[D]) =
  t.refresh.add(refresh)

# Forward declaration
proc clone*[D](comp: Component[D]): Component[D]
proc compile*[D](tf: Config[D], node: dom.Node): Component[D]

proc mount*[D](t: MatchConfig[D], conf: Config[D], node: dom.Node) =
  t.mount = compile(conf, node)

proc mount*[D](t: MatchConfig[D], comp: Component[D]) =
  t.mount = clone(comp)

proc match*[D](t: Config[D] | MatchConfig[D], selector: string, fetchData: ProcGetValue[D], refreshProc: ProcRefresh[D]) =
  refresh(t.match(selector, fetchData), refreshProc)

proc iter*[D](t: Config[D] | MatchConfig[D], selector: string, fetchData: ProcGetValue[D], actions: proc(x: MatchConfig[D]) = nil): MatchConfig[D] {.discardable.} =
  result = MatchConfig[t.D](
    selector: selector,
    fetchData: fetchData,
    refresh: @[],
    mount: nil,
    iter: true,
    matches: @[])
  t.matches.add(result)
  if actions != nil:
    actions(result)

proc compile[D](cfg: MatchConfig[D], node: dom.Node): CompMatch[D] =
  let matched_node = node.querySelector(cfg.selector)
  if matched_node == nil:
    let selector = cfg.selector
    raise newException(CompileError, &"Cannot match selector '{selector}'")

  var match = CompMatch[D](
    refresh: cfg.refresh,
    fetchData: cfg.fetchData,
    iter: cfg.iter,
    node: matched_node)
  match.node = matched_node
  if match.iter:
    match.anchor = matched_node.ownerDocument.createComment(matched_node.outerHTML)
    match.mount_template = cfg.mount
    match.match_templates = cfg.matches
    match.items = @[]
    matched_node.parentNode.replaceChild(match.anchor, matched_node)
  else:
    match.matches = @[]
    if cfg.mount != nil:
      match.mount = clone(cfg.mount)
      matched_node.parentNode.replaceChild(match.mount.node, matched_node)
    else:
      for submatch in cfg.matches:
        match.matches.add(submatch.compile(matched_node))
  return match

proc compile[D](tfs: seq[MatchConfig[D]], node: dom.Node): seq[CompMatch[D]] =
  result = @[]
  for tf in tfs:
    result.add(compile(tf, node))

proc compile*[D](tf: Config[D], node: dom.Node): Component[D] =
  var t = new(Component[D])
  t.config = tf
  t.matches = @[]
  t.original_node = node
  t.node = node.cloneNode(true)
  for matchTmpl in tf.matches:
    var match = compile(matchTmpl, t.node)
    t.matches.add(match)
  return t

proc clone*[D](comp: Component[D]): Component[D] =
  return comp.config.compile(comp.original_node)

proc createIterItem[D](match: CompMatch[D], parentNode: dom.Node): CompMatchItem[D] =
  var comp: Component[D] = nil
  var node: dom.Node
  if match.mount_template != nil:
    comp = clone(match.mount_template)
    node = comp.node
  else:
    node = match.node.cloneNode(true)
  result = CompMatchItem[D](
    mount: comp,
    node: node,
    matches: compile(match.match_templates, node))
  parentNode.insertBefore(node, match.anchor)

proc detach[D](iter_item: CompMatchItem[D], parentNode: dom.Node) =
  parentNode.removeChild(iter_item.node)

# Forward declaration
proc update*[D](t: Component[D], data: D, refresh: bool = false)

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

      # Refresh mounts
      if iter_item.mount != nil:
        iter_item.mount.update(item, refresh)

      # Refresh the submatches
      for submatch in iter_item.matches:
        submatch.update(item, refresh)

      # Refresh the node
      for refreshProc in match.refresh:
        refreshProc(iter_item.node, item)

      i = i + 1

    # Remove extra items if there is any because the list shrinked
    while i < len(match.items):
      detach(pop(match.items), parentNode)
  else:
    var node = match.node

    # Refresh mounts
    if match.mount != nil:
      node = match.mount.node
      match.mount.update(val, refresh)

    # Refresh the submatches
    for submatch in match.matches:
      submatch.update(val, refresh)

    # Refresh the node
    for refreshProc in match.refresh:
      refreshProc(node, val)

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

