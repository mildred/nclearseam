import sequtils
import strformat
import system
import ./dom

type
  CompileError* = object of CatchableError

  ProcRefresh*[D]           = proc(node: dom.Node, data: D)
  ProcGetValue*[D]          = proc(data: D): D
  ProcTypeConverter*[D1,D2] = proc(data: D1): D2
  ProcIter*[D2]             = proc(): tuple[ok: bool, data: D2]
  ProcIterator*[D1,D2]      = proc(d: D1): ProcIter[D2]

  IterItem[D] = ref object
    updateComp:  proc(comp: ComponentInterface[D], refresh: bool)
    updateMatch: proc(m: CompMatch[D], refresh: bool)
    refresh:     proc(refreshProc: ProcRefresh[D], node: dom.Node)
    next:        proc(): IterItem[D]
  ProcIterInternal*[D] = proc(data: D): IterItem[D]

  #
  # Config: Global component configuration
  #

  Config*[D] = ref object
    matches: seq[MatchConfigInterface[D]]

  # MatchConfig: configuration for a selector match

  MatchConfig*[D,D2] = ref object
    selector: string
    refresh: seq[ProcRefresh[D2]]
    matches: seq[MatchConfigInterface[D2]]
    mount: ComponentInterface[D2]
    case iter: bool
    of false:
      convert: ProcTypeConverter[D,D2]
    of true:
      iterate: ProcIterator[D,D2]

  MatchConfigInterface[D] = ref object
    compile: proc(node: dom.Node): CompMatchInterface[D]

  #
  # Component: Global component object
  #

  Component*[D] = ref object
    config: Config[D]
    matches: seq[CompMatchInterface[D]]
    node: dom.Node
    original_node: dom.Node

  ComponentInterface*[D] = ref object
    node*:   proc(): dom.Node
    update*: proc(data: D, refresh: bool)
    clone*:  proc(): ComponentInterface[D]

  # CompMatch: handle association between DOM and a selector match

  CompMatch[D,D2] = ref object
    refresh: seq[ProcRefresh[D2]]
    node: dom.Node
    oldValue: D
    case iter:bool
    of false:
      convert: ProcTypeConverter[D,D2]
      mount_source: ComponentInterface[D2]
      mount: ComponentInterface[D2]
      matches: seq[CompMatchInterface[D2]]
    of true:
      iterate: ProcIterator[D,D2]
      mount_template: ComponentInterface[D2]
      match_templates: seq[MatchConfigInterface[D2]]
      items: seq[CompMatchItem[D2]]
      anchor: dom.Node

  CompMatchInterface[D] = ref object
    update: proc(data: D, refresh: bool)

  # CompMatchItem: handle iterations

  CompMatchItem[D2] = ref object
    node: dom.Node
    matches: seq[CompMatchInterface[D2]]
    mount: ComponentInterface[D2]

#
# Forward declaration interface conversion
#

func asInterface*[D,D2](config: MatchConfig[D,D2]): MatchConfigInterface[D]
func asInterface*[D,D2](match: CompMatch[D,D2]): CompMatchInterface[D]
func asInterface*[D](comp: Component[D]): ComponentInterface[D]
func asInterface*[D,D2](comp: Component[D2], convert: ProcTypeConverter[D,D2]): ComponentInterface[D]

#
# Forward declaration of the public API
#

proc compile*[D](node: dom.Node, tf: Config[D]): Component[D]
proc clone*[D](comp: Component[D]): Component[D]

#
# Utils
#

proc id[D](data: D): D = data

#
# Configuration DSL
#
# create:  creates a new config
# match:   match an element using a selector and allows to manipulate it
# refresh: calls a callback each time the element needs refreshing
# mount:   mount another component at the element location
# iter:    duplicate the element using a collection iterator
#

proc create*[D](): Config[D] =
  return new(Config[D])

proc create*[D](d: typedesc[D], configurator: proc(c: Config[D])): Config[D] =
  result = new(Config[D])
  configurator(result)

proc match*[X,D,D2](c: MatchConfig[X,D], selector: string, convert: ProcTypeConverter[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  result = MatchConfig[D,D2](
    selector: selector,
    refresh: @[],
    mount: nil,
    iter: false,
    convert: convert)
  c.matches.add(result.asInterface())
  if actions != nil:
    actions(result)

proc match*[D,D2](c: Config[D], selector: string, convert: ProcTypeConverter[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  result = MatchConfig[D,D2](
    selector: selector,
    refresh: @[],
    mount: nil,
    iter: false,
    convert: convert)
  c.matches.add(result.asInterface())
  if actions != nil:
    actions(result)

proc refresh*[X,D](c: MatchConfig[X,D], refresh: ProcRefresh[D]) =
  c.refresh.add(refresh)

proc match*[D](c: Config[D], selector: string, actions: proc(x: MatchConfig[D,D]) = nil): MatchConfig[D,D] {.discardable.} =
  match[D,D](c, selector, id[D], actions)

proc match*[X,D](c: MatchConfig[X,D], selector: string, actions: proc(x: MatchConfig[D,D]) = nil): MatchConfig[D,D] {.discardable.} =
  match[X,D,D](c, selector, id[D], actions)

proc match*[D](c: Config[D], selector: string, refreshProc: ProcRefresh[D]) =
  refresh(match[D](c, selector), refreshProc)

proc match*[X,D](c: MatchConfig[X,D], selector: string, refreshProc: ProcRefresh[D]) =
  refresh(match[X,D](c, selector), refreshProc)

proc mount*[X,D](c: MatchConfig[X,D], conf: Config[D], node: dom.Node) =
  assert(conf != nil, "mounted configuration cannot be nil")
  assert(node != nil, "mounted node cannot be nil")
  c.mount = asInterface(compile(conf, node))

proc mount*[X,D](c: MatchConfig[X,D], comp: Component[D]) =
  assert(comp != nil, "mounted component cannot be nil")
  c.mount = asInterface(clone(comp))

proc mount*[X,D](c: MatchConfig[X,D], comp: ComponentInterface[D]) =
  assert(comp != nil, "mounted component cannot be nil")
  c.mount = comp.clone()

proc mount*[X,D,D2](c: MatchConfig[X,D], comp: Component[D2], convert: ProcTypeConverter[D,D2]) =
  assert(comp != nil, "mounted component cannot be nil")
  c.mount = asInterface[D](clone[D2](comp), convert)

proc iter*[D,D2](c: Config[D], selector: string, iter: ProcIterator[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  result = MatchConfig[D,D2](
    selector: selector,
    refresh: @[],
    mount: nil,
    iter: true,
    iterate: iter,
    matches: @[])
  c.matches.add(result.asInterface())
  if actions != nil:
    actions(result)

proc iter*[X,D,D2](c: MatchConfig[X,D], selector: string, iter: ProcIterator[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  result = MatchConfig[D,D2](
    selector: selector,
    refresh: @[],
    mount: nil,
    iter: true,
    iterate: iter,
    matches: @[])
  c.matches.add(result.asInterface())
  if actions != nil:
    actions(result)

#
# Compile a config to a component
#

proc compile[D,D2](cfg: MatchConfig[D,D2], node: dom.Node): CompMatch[D,D2] =
  let matched_node = node.querySelector(cfg.selector)
  if matched_node == nil:
    let selector = cfg.selector
    raise newException(CompileError, &"Cannot match selector '{selector}'")

  var match = CompMatch[D,D2](
    refresh: cfg.refresh,
    iter: cfg.iter,
    node: matched_node)
  match.node = matched_node
  if match.iter:
    match.iterate = cfg.iterate
    match.anchor = matched_node.ownerDocument.createComment(matched_node.outerHTML)
    match.mount_template = cfg.mount
    match.match_templates = cfg.matches
    match.items = @[]
    matched_node.parentNode.replaceChild(match.anchor, matched_node)
  else:
    match.convert = cfg.convert
    match.matches = @[]
    match.mount = nil
    if cfg.mount != nil:
      match.mount_source = cfg.mount
    else:
      for submatch in cfg.matches:
        match.matches.add(submatch.compile(matched_node))
  return match

proc compile[D](cfgs: seq[MatchConfigInterface[D]], node: dom.Node): seq[CompMatchInterface[D]] =
  result = @[]
  for cfg in cfgs:
    result.add(cfg.compile(node))

proc compile*[D](cfg: Config[D], node: dom.Node): Component[D] =
  result = new(Component[D])
  result.config        = cfg
  result.original_node = node
  result.node          = node.cloneNode(true)
  result.matches       = compile(cfg.matches, result.node)

#
# Update a component match
#

# CreateIterItem is a helper procedure to create iteration items
proc createIterItem[D,D2](match: CompMatch[D,D2], parentNode: dom.Node): CompMatchItem[D2] =
  var comp: ComponentInterface[D2] = nil
  var node: dom.Node
  if match.mount_template != nil:
    comp = match.mount_template.clone()
    node = comp.node()
  else:
    node = match.node.cloneNode(true)
  result = CompMatchItem[D2](
    mount: comp,
    node: node,
    matches: compile(match.match_templates, node))
  parentNode.insertBefore(node, match.anchor)

# detach is a helper procedure to detach a node from an iter item
proc detach[D2](iter_item: CompMatchItem[D2], parentNode: dom.Node) =
  parentNode.removeChild(iter_item.node)

proc update*[D,D2](match: CompMatch[D,D2], val: D, refresh: bool) =
  mixin get, `==`
  if not refresh and val == match.oldValue:
    return

  match.oldValue = val
  if match.iter:
    var i = 0
    let parentNode = match.anchor.parentNode
    var itf = match.iterate(val)
    while true:
      var it = itf()
      if it[0] == false: break
      var item = it[1]

      if i > 10:
        break

      var iter_item: CompMatchItem[D2]

      # Create item if needed
      if i < len(match.items):
        iter_item = match.items[i]
      else:
        iter_item = createIterItem[D,D2](match, parentNode)
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
    var convertedVal = match.convert(val)

    # Mount the child
    if match.mount == nil and match.mount_source != nil:
      match.mount = match.mount_source.clone()
      node.parentNode.replaceChild(match.mount.node(), node)

    # Refresh mounts
    if match.mount != nil:
      node = match.mount.node()
      match.mount.update(convertedVal, refresh)

    # Refresh the submatches
    for submatch in match.matches:
      submatch.update(convertedVal, refresh)

    # Refresh the node
    for refreshProc in match.refresh:
      refreshProc(node, convertedVal)

#
# API
#
# compile: create a component using a config and Node
# clone:   create a separate component from an existing component
# update:  update dataset and update the DOM
# attach:  attach DOM node to a parent in the document
# detach:  detach managed DOM node from its parent
#

proc compile*[D](node: dom.Node, tf: Config[D]): Component[D] =
  compile(tf, node)

proc compile*[D](d: typedesc[D], node: dom.Node, configurator: proc(c: Config[D])): Component[D] =
  compile(create[D](d, configurator), node)

proc clone*[D](comp: Component[D]): Component[D] =
  return comp.config.compile(comp.original_node)

proc update*[D](t: Component[D], data: D, refresh: bool = false) =
  mixin get, `==`, items
  for match in t.matches:
    match.update(data, refresh)

proc attach*[D](t: Component[D], target, anchor: dom.Node, data: D) =
  t.update(data, refresh = true)
  target.insertBefore(t.node, anchor)

proc detach*(t: Component) =
  t.node.parentNode.removeChild(t.node)

#
# Interfaces
#
# CompMatchInterface: handles hiding away extra generic parameter
# MatchConfigInterface: handles hiding away extra generic parameter
#

func asInterface*[D,D2](match: CompMatch[D,D2]): CompMatchInterface[D] =
  result = CompMatchInterface[D](
    update: proc(data: D, refresh: bool) = update[D,D2](match, data, refresh)
  )

func asInterface*[D,D2](config: MatchConfig[D,D2]): MatchConfigInterface[D] =
  result = MatchConfigInterface[D](
    compile: proc(node: dom.Node): CompMatchInterface[D] = compile(config, node).asInterface()
  )

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

# late binding of a componnent that is not there yet
proc late*[D](lateComp: proc(): Component[D]): ComponentInterface[D] =
  var comp: Component[D] = nil

  proc resolveComp() :Component[D] =
    if comp == nil:
      var late = lateComp()
      assert(late != nil, "late component not resolved in time")
      comp = late
    return comp

  result = ComponentInterface[D](
    node: proc(): dom.Node =
      resolveComp().node,
    update: proc(data: D, refresh: bool) =
      resolveComp().update(data, refresh),
    clone: proc(): ComponentInterface[D] =
      late(proc(): Component[D] = clone(resolveComp()))
  )

#
# Helper procedures to create iterator functions
#

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
    result = (true, arr[it])
    it = it + 1

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

