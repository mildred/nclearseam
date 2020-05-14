import sequtils
import strformat
import system
import ./dom

type
  CompileError* = object of CatchableError

  ProcRefresh*[D]           = proc(node: dom.Node, data: D)
  ProcGetValue*[D]          = proc(data: D): D
  ProcTypeConverter*[D1,D2] = proc(data: D1): D2
  ProcIter*[D2]          = proc(): tuple[ok: bool, data: D2]
  ProcIterator*[D1,D2]      = proc(d: D1): ProcIter[D2]

  IterItem[D] = ref object
    updateComp:  proc(comp: ComponentInterface[D], refresh: bool)
    updateMatch: proc(m: CompMatch[D], refresh: bool)
    refresh:     proc(refreshProc: ProcRefresh[D], node: dom.Node)
    next:        proc(): IterItem[D]
  ProcIterInternal*[D] = proc(data: D): IterItem[D]

  ComponentInterface*[D] = ref object
    node*:   proc(): dom.Node
    update*: proc(data: D, refresh: bool)
    clone*:  proc(): ComponentInterface[D]

  MatchConfigImplementation[D] = ref object
    selector: proc(): string
    refresh: proc(): seq[ProcRefresh[D]]
    fetchData: proc(): ProcGetValue[D]
    matches: proc(): seq[MatchConfigInterface[D]]
    mount: proc(): ComponentInterface[D]
    iter: proc(): bool
    iterate: proc(): ProcIterInternal[D]
  MatchConfigInterface[D] = ref object
    direct: MatchConfig[D]
    implem: MatchConfigImplementation[D]

  MatchConfig*[D] = ref object
    selector: string
    refresh: seq[ProcRefresh[D]]
    fetchData: ProcGetValue[D]
    matches: seq[MatchConfigInterface[D]]
    mount: ComponentInterface[D]
    iter: bool
    iterate: ProcIterInternal[D]

  Config*[D] = ref object
    matches: seq[MatchConfigInterface[D]]

  CompMatchItem[D] = ref object
    node: dom.Node
    matches: seq[CompMatch[D]]
    mount: ComponentInterface[D]

  CompMatch[D] = ref object
    refresh: seq[ProcRefresh[D]]
    fetchData: ProcGetValue[D]
    node: dom.Node
    oldValue: D
    case iter:bool
    of false:
      mount: ComponentInterface[D]
      matches: seq[CompMatch[D]]
    of true:
      iterate: ProcIterInternal[D]
      mount_template: ComponentInterface[D]
      match_templates: seq[MatchConfigInterface[D]]
      items: seq[CompMatchItem[D]]
      anchor: dom.Node

  Component*[D] = ref object
    config: Config[D]
    matches: seq[CompMatch[D]]
    node: dom.Node
    original_node: dom.Node

proc createIterator[D1,D2](iterate: ProcIterator[D1,D2]): ProcIterInternal[D1]
proc dataIterator[D](data: D): ProcIter[D]

proc asInterface[D](m: MatchConfig[D]): MatchConfigInterface[D] =
  result = MatchConfigInterface[D](direct: m, implem: nil)

proc selector[D](m: MatchConfigInterface[D]): string =
  if m.direct != nil: m.direct.selector else: m.implem.selector()

proc refresh[D](m: MatchConfigInterface[D]): seq[ProcRefresh[D]] =
  if m.direct != nil: m.direct.refresh else: m.implem.refresh()

proc fetchData[D](m: MatchConfigInterface[D]): ProcGetValue[D] =
  if m.direct != nil: m.direct.fetchData else: m.implem.fetchData()

proc matches[D](m: MatchConfigInterface[D]): seq[MatchConfigInterface[D]] =
  if m.direct != nil: m.direct.matches else: m.implem.matches()

proc mount[D](m: MatchConfigInterface[D]): ComponentInterface[D] =
  if m.direct != nil: m.direct.mount else: m.implem.mount()

proc iter[D](m: MatchConfigInterface[D]): bool =
  if m.direct != nil: m.direct.iter else: m.implem.iter()

proc iterate[D](m: MatchConfigInterface[D]): ProcIterInternal[D] =
  if m.direct != nil: m.direct.iterate else: m.implem.iterate()

proc create*[D](): Config[D] =
  return new(Config[D])

proc create*[D](d: typedesc[D], configurator: proc(c: Config[D])): Config[D] =
  result = new(Config[D])
  configurator(result)

proc compile*[D](node: dom.Node, tf: Config[D]): Component[D]
proc compile*[D](d: typedesc[D], node: dom.Node, configurator: proc(c: Config[D])): Component[D] =
  let config = new(Config[D])
  configurator(config)
  compile(config, node)

proc match*[D](t: Config[D] | MatchConfig[D], selector: string, fetchData: ProcGetValue[D], actions: proc(x: MatchConfig[D]) = nil): MatchConfig[D] {.discardable.} =
  result = MatchConfig[t.D](
    selector: selector,
    fetchData: fetchData,
    refresh: @[],
    mount: nil,
    iter: false)
  t.matches.add(result.asInterface())
  if actions != nil:
    actions(result)

proc match*[D](t: Config[D] | MatchConfig[D], selector: string, actions: proc(x: MatchConfig[D]) = nil): MatchConfig[D] {.discardable.} =
  match(t, selector, nil, actions)

proc refresh*[D](t: MatchConfig[D], refresh: ProcRefresh[D]) =
  t.refresh.add(refresh)

# Forward declaration
proc update*[D](t: Component[D], data: D, refresh: bool = false)
proc clone*[D](comp: Component[D]): Component[D]
proc compile*[D](tf: Config[D], node: dom.Node): Component[D]

func asInterface*[D](comp: Component[D]): ComponentInterface[D] =
  result = ComponentInterface[D](
    node: proc(): dom.Node =
      comp.node,
    update: proc(data: D, refresh: bool) =
      comp.update(data, refresh),
    clone: (proc(): ComponentInterface[D] =
      asInterface(clone(comp))))

func asInterface*[D,D2](comp: Component[D2], convert: ProcTypeConverter[D,D2]): ComponentInterface[D] =
  result = ComponentInterface[D](
    node: proc(): dom.Node =
      comp.node,
    update: proc(data: D, refresh: bool) =
      comp.update(convert(data), refresh),
    clone: (proc(): ComponentInterface[D] =
      asInterface(clone(comp), convert)))

proc mount*[D](t: MatchConfig[D], conf: Config[D], node: dom.Node) =
  t.mount = asInterface(compile(conf, node))

proc mount*[D](t: MatchConfig[D], comp: Component[D]) =
  t.mount = asInterface(clone(comp))

proc mount*[D](t: MatchConfig[D], comp: ComponentInterface[D]) =
  t.mount = comp.clone()

proc mount*[D,D2](t: MatchConfig[D], comp: Component[D2], convert: ProcTypeConverter[D,D2]) =
  t.mount = asInterface[D](clone[D2](comp), convert)

proc match*[D](t: Config[D] | MatchConfig[D], selector: string, fetchData: ProcGetValue[D], refreshProc: ProcRefresh[D]) =
  refresh(t.match(selector, fetchData), refreshProc)

proc match*[D](t: Config[D] | MatchConfig[D], selector: string, refreshProc: ProcRefresh[D]) =
  refresh(t.match(selector), refreshProc)

proc iter*[D,D2](t: Config[D] | MatchConfig[D], selector: string, fetchData: ProcGetValue[D], iter: ProcIterInternal[D], actions: proc(x: MatchConfig[D2]) = nil): MatchConfig[D2] {.discardable.} =
  result = MatchConfig[D2](
    selector: selector,
    fetchData: fetchData,
    refresh: @[],
    mount: nil,
    iter: true,
    iterate: createIterator[D,D2](iter),
    matches: @[])
  t.matches.add(result.asInterface())
  if actions != nil:
    actions(result)

proc iter*[D](t: Config[D] | MatchConfig[D], selector: string, fetchData: ProcGetValue[D], actions: proc(x: MatchConfig[D]) = nil): MatchConfig[D] {.discardable.} =
  let iterate: ProcIterator[D,D] = dataIterator
  iter[D,D](t, selector, fetchData, iterate, actions)

proc iter*[D,D2](t: Config[D] | MatchConfig[D], selector: string, iter: ProcIterator[D,D2], actions: proc(x: MatchConfig[D2]) = nil): MatchConfig[D2] {.discardable.} =
  iter(t, selector, nil, iter, actions)

proc compile[D](cfg: MatchConfigInterface[D], node: dom.Node): CompMatch[D] =
  let matched_node = node.querySelector(cfg.selector())
  if matched_node == nil:
    let selector = cfg.selector()
    raise newException(CompileError, &"Cannot match selector '{selector}'")

  var match = CompMatch[D](
    refresh: cfg.refresh(),
    fetchData: cfg.fetchData(),
    iter: cfg.iter(),
    node: matched_node)
  match.node = matched_node
  if match.iter:
    match.iterate = cfg.iterate()
    match.anchor = matched_node.ownerDocument.createComment(matched_node.outerHTML)
    match.mount_template = cfg.mount()
    match.match_templates = cfg.matches()
    match.items = @[]
    matched_node.parentNode.replaceChild(match.anchor, matched_node)
  else:
    match.matches = @[]
    if cfg.mount() != nil:
      match.mount = cfg.mount().clone()
      matched_node.parentNode.replaceChild(match.mount.node(), matched_node)
    else:
      for submatch in cfg.matches():
        match.matches.add(submatch.compile(matched_node))
  return match

proc compile[D](tfs: seq[MatchConfigInterface[D]], node: dom.Node): seq[CompMatch[D]] =
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

proc compile*[D](node: dom.Node, tf: Config[D]): Component[D] =
  compile(tf, node)

proc clone*[D](comp: Component[D]): Component[D] =
  return comp.config.compile(comp.original_node)

proc createIterItem[D](match: CompMatch[D], parentNode: dom.Node): CompMatchItem[D] =
  var comp: ComponentInterface[D] = nil
  var node: dom.Node
  if match.mount_template != nil:
    comp = match.mount_template.clone()
    node = comp.node()
  else:
    node = match.node.cloneNode(true)
  result = CompMatchItem[D](
    mount: comp,
    node: node,
    matches: compile(match.match_templates, node))
  parentNode.insertBefore(node, match.anchor)

proc detach[D](iter_item: CompMatchItem[D], parentNode: dom.Node) =
  parentNode.removeChild(iter_item.node)

proc update*[D](match: CompMatch[D], data: D, refresh: bool = false) =
  mixin get, `==`, items
  let val = if match.fetchData != nil: match.fetchData(data) else: data
  if not refresh and val == match.oldValue:
    return

  match.oldValue = val
  if match.iter:
    var i = 0
    let parentNode = match.anchor.parentNode
    #for item in items(val):
    var it = match.iterate(val)
    while it != nil:
      var iter_item: CompMatchItem[D]

      # Create item if needed
      if i < len(match.items):
        iter_item = match.items[i]
      else:
        iter_item = createIterItem(match, parentNode)
        match.items.add(iter_item)

      # Refresh mounts
      if iter_item.mount != nil:
        #iter_item.mount.update(item, refresh)
        it.updateComp(iter_item.mount, refresh)

      # Refresh the submatches
      for submatch in iter_item.matches:
        #submatch.update(item, refresh)
        it.updateMatch(submatch, refresh)

      # Refresh the node
      for refreshProc in match.refresh:
        #refreshProc(iter_item.node, item)
        it.refresh(refreshProc, iter_item.node)

      i = i + 1

    # Remove extra items if there is any because the list shrinked
    while i < len(match.items):
      detach(pop(match.items), parentNode)
  else:
    var node = match.node

    # Refresh mounts
    if match.mount != nil:
      node = match.mount.node()
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

func get*[K,D](typ: typedesc[D], keys: varargs[K]): ProcGetValue[D] =
  mixin `[]`
  let keys = @keys
  return proc(node: D): D =
    result = node
    for key in items(keys): result = result[key]

#proc dataIterator[D](data: D): IterItem[D] =
#  mixin items
#  #var it: proc = items # instanciate the iterator
#  let arr: seq[D] = @[]
#  for item in items(data):
#    arr.add(item)
#  var it = 0
#
#  proc next(): IterItem[D] =
#    #let item = it(data)
#    #if finished(it): return nil
#    if it >= len(arr): return nil
#    let item = arr[it]
#    return IterItem[D](
#      updateComp:  (proc(comp: ComponentInterface[D], refresh: bool) = update(comp, item, refresh)),
#      updateMatch: (proc(m: CompMatch[D], refresh: bool) = update(m, item, refresh)),
#      refresh:     (proc(refreshProc: ProcRefresh[D], node: dom.Node) = refreshProc(node, item)),
#      next:        next
#    )
#
#  return next()

proc seqIterator*[D](arr: seq[D]): ProcIter[D] =
  #mixin items
  #var it = items # Instanciate iterator
  var it = 0
  var empty: D

  proc next(): tuple[ok: bool, data: D] =
    #let item: D = it(data)
    #if finished(it): return (false, item)
    #else: return (true, data)
    if it >= len(arr): return (false, empty)
    else: return (true, arr[it])

  return next

proc dataIterator[D](data: D): ProcIter[D] =
  mixin items
  var arr: seq[D] = @[]
  for item in items(data):
    arr.add(item)
  return seqIterator[D](arr)

proc createIterator[D,D2](iterate: ProcIterator[D,D2]): ProcIterInternal[D] =
  var nextItem: ProcIter[D2] = nil
  let iterate1 = iterate

  proc next[D,D2](): IterItem[D] =
    let item = nextItem()
    if item[0] == false: return nil
    return IterItem[D](
      updateComp:  (proc(comp: ComponentInterface[D], refresh: bool) = comp.update(item[1], refresh)),
      updateMatch: (proc(m: CompMatch[D], refresh: bool) = update(m, item[1], refresh)),
      refresh:     (proc(refreshProc: ProcRefresh[D], node: dom.Node) = refreshProc(node, item[1])),
      next:        next
    )

  proc iter[D,D2](d1: D): IterItem[D] =
    nextItem = iterate1(d1)
    return next[D,D2]()

  return iter

