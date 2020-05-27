import sequtils
import strformat
import system
import ./dom

type
  CompileError* = object of CatchableError ##\
  ## Parent type for all errors

  CompileSelectorError* = object of CompileError ## \
  ## Type for an object that can be raised in case there is a problem \
  ## with the template configuration such as a CSS selector not matching the \
  ## given template DOM Node

  CompileLateError* = object of CompileError ## \
  ## Represents an error wen a late binding fails.

  ProcConfig*[D] = proc(c: Component[D]) ## \
  ## procedure callback that is called upon compilation to configure the
  ## component

  ProcInit* = proc(node: dom.Node) ## \
  ## Procedure callback that is called whenever a part of a template needs to \
  ## be initialized (such as installing event handlers)

  ProcRefresh*[D] = proc(node: dom.Node, data: D) ## \
  ## Procedure callback that is called whenever a part of a template needs to \
  ## be refreshed on data change.

  ProcTypeConverter*[D1,D2] = proc(data: D1): D2 ## \
  ## Procedure that fetches a part of a larger data object and return a \
  ## smaller data set for sub-parts of the template.

  ProcTypeSelectorSerial*[D1,D2] = proc(data: D1, serial: var int): D2 ## \
  ## Procedure that fetches a part of a larger dataset and returns a smaller
  ## part. Takes a serial variable corresponding to the older value from last
  ## run and set it to a serial value representing the current value.
  ##
  ## Serial changes means that the value has changed. if the serial has not
  ## changed since last run, the value is considered identical and update is not
  ## performed.

  ProcTypeSelectorCompare*[D1,D2] = proc(data: D1, oldData: D2): tuple[data: D2, changed: bool] ## \
  ## Procedure that fetches a part of a larger dataset and returns a smaller
  ## part. Takes the previous value returned and return true if the new value
  ## has changed compared to the old

  TypeSelectorKind = enum
    SimpleTypeSelector,
    SerialTypeSelector,
    CompareTypeSelector

  TypeSelector[D1,D2] = object
    case kind: TypeSelectorKind
    of SimpleTypeSelector:
      simple: ProcTypeConverter[D1,D2]
    of SerialTypeSelector:
      serial: ProcTypeSelectorSerial[D1,D2]
    of CompareTypeSelector:
      compare: ProcTypeSelectorCompare[D1,D2]

  ProcIter*[D2]        = proc(): tuple[ok: bool, data: D2] ## part of `ProcIterator`
  ProcIterator*[D1,D2] = proc(d: D1): ProcIter[D2] ## \
  ## Procedure performing an iteration (as iterators are not supported by Nim \
  ## JavaScript backend). Accepts a data set and returns a procedure that when \
  ## called, return the next item of the iteration, and a boolean indicating \
  ## the end of the iteration.

  ProcIterSerial*[D2]        = proc(serial: var int): tuple[ok: bool, data: D2] ## part of `ProcIteratorSerial`
  ProcIteratorSerial*[D1,D2] = proc(d: D1): ProcIterSerial[D2] ## \
  ## Procedure performing an iteration (as iterators are not supported by Nim \
  ## JavaScript backend). Accepts a data set and returns a procedure that when \
  ## called, return the next item of the iteration, and a boolean indicating \
  ## the end of the iteration. At each iteration, the procedure takes a serial
  ## variable and sets it to a serial that indicated if the value has changed
  ## from previous runs.

  IteratorKind* = enum
    SimpleIterator,
    SerialIterator

  Iterator*[D1,D2] = object
    case kind: IteratorKind
    of SimpleIterator:
      simple: ProcIterator[D1,D2]
    of SerialIterator:
      serial: ProcIteratorSerial[D1,D2]

  IterItem[D] = ref object
    updateComp:  proc(comp: ComponentInterface[D], refresh: bool)
    updateMatch: proc(m: CompMatch[D], refresh: bool)
    refresh:     proc(refreshProc: ProcRefresh[D], node: dom.Node)
    next:        proc(): IterItem[D]
  ProcIterInternal[D] = proc(data: D): IterItem[D]

  #
  # Config: Global component configuration
  #

  Config*[D] = ref object of RootObj
    ## Represents a template configuration, not yet associated with a DOM Node
    cmatches: seq[MatchConfigInterface[D]]
    config: ProcConfig[D]

  # MatchConfig: configuration for a selector match

  MatchConfig*[D,D2] = ref object
    ## Part of a template configuration, related to particular sub-section \
    ## represented by a CSS selector.
    selector: string
    refresh: seq[ProcRefresh[D2]]
    init: seq[ProcInit]
    cmatches: seq[MatchConfigInterface[D2]]
    mount: ComponentInterface[D2]
    case iter: bool
    of false:
      convert: TypeSelector[D,D2]
    of true:
      iterate: Iterator[D,D2]

  MatchConfigInterface[D] = ref object
    compile: proc(node: dom.Node): CompMatchInterface[D]

  #
  # Component: Global component object
  #

  Component*[D] = ref object of Config[D]
    ## Represents an instanciated template, a `Config` that has been compiled \
    ## with a DOM node.
    matches: seq[CompMatchInterface[D]]
    node: dom.Node
    original_node: dom.Node
    data*: D

  ComponentInterface*[D] = ref object
    ## Wrapper around a `Component`, allowing the generic type to be converted.
    node*:   proc(): dom.Node
    update*: proc(data: D, refresh: bool)
    clone*:  proc(): ComponentInterface[D]

  # CompMatch: handle association between DOM and a selector match

  CompMatch[D,D2] = ref object
    refresh: seq[ProcRefresh[D2]]
    init: seq[ProcInit]
    node: dom.Node
    case iter: bool
    of false:
      case selectorKind: TypeSelectorKind
      of SerialTypeSelector:
        serial: int
      of CompareTypeSelector:
        value: D2
      else: discard
      convert: TypeSelector[D,D2]
      mount_source: ComponentInterface[D2]
      mount: ComponentInterface[D2]
      matches: seq[CompMatchInterface[D2]]
      inited: bool
    of true:
      iterate: Iterator[D,D2]
      mount_template: ComponentInterface[D2]
      match_templates: seq[MatchConfigInterface[D2]]
      items: seq[CompMatchItem[D2]]
      anchor: dom.Node

  CompMatchInterface[D] = ref object
    update: proc(data: D, refresh: bool)

  # CompMatchItem: handle iterations

  CompMatchItem[D2] = ref object
    serial: int
    node: dom.Node
    matches: seq[CompMatchInterface[D2]]
    mount: ComponentInterface[D2]

#
# Forward declaration interface conversion
#

func asInterface[D,D2](config: MatchConfig[D,D2]): MatchConfigInterface[D]
func asInterface[D,D2](match: CompMatch[D,D2]): CompMatchInterface[D]
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
  ## Create a new empty configuration. Takes a dataset type as first argument
  return new(Config[D])

proc create*[D](d: typedesc[D], config: ProcConfig[D]): Config[D] =
  ## Create a new empty configuration but allows to pass a procedure to modify
  ## the configuration

  #runnableExamples:
  #  ## Hello World configuration
  #  type HelloName = ref object
  #    name: string

  #  let tmpl = create(HelloName) do(c: auto):
  #    c.match(".name").refresh do(node: dom.Node, data: HelloName):
  #      node.textContents = data.name

  result = new(Config[D])
  result.config = config

proc match[X,D,D2](c: MatchConfig[X,D], selector: string, convert: TypeSelector[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Declares a sub-match. The selector is run to find the DOM node that the
  ## sub-match will modify, and the convert procedure allows to refine the
  ## dataset when the sub-match only needs a portion of this dataset. The
  ## optional actions procedure can be used to further configure the sub-match.
  result = MatchConfig[D,D2](
    selector: selector,
    refresh: @[],
    init: @[],
    mount: nil,
    iter: false,
    convert: convert)
  c.cmatches.add(result.asInterface())
  if actions != nil:
    actions(result)

proc match[D,D2](c: Config[D], selector: string, convert: TypeSelector[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant for `Config`
  result = MatchConfig[D,D2](
    selector: selector,
    refresh: @[],
    init: @[],
    mount: nil,
    iter: false,
    convert: convert)
  c.cmatches.add(result.asInterface())
  if actions != nil:
    actions(result)

proc match*[X,D,D2](c: MatchConfig[X,D], selector: string, convert: ProcTypeConverter[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Declares a sub-match. The selector is run to find the DOM node that the
  ## sub-match will modify, and the convert procedure allows to refine the
  ## dataset when the sub-match only needs a portion of this dataset. The
  ## optional actions procedure can be used to further configure the sub-match.
  ##
  ## Match variant with convert procedure as simple `ProcTypeConverter`.
  let typeSelector = TypeSelector[D,D2](
    kind: SimpleTypeSelector,
    simple: convert)
  result = match(c, selector, typeSelector, actions)

proc match*[D,D2](c: Config[D], selector: string, convert: ProcTypeConverter[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeConverter`.
  let typeSelector = TypeSelector[D,D2](
    kind: SimpleTypeSelector,
    simple: convert)
  result = match(c, selector, typeSelector, actions)

proc match*[X,D,D2](c: MatchConfig[X,D], selector: string, convert: ProcTypeConverter[D,D2], equal: proc(d1, d2: D2): bool, actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeConverter` with
  ## equal procedure
  let typeSelector = TypeSelector[D,D2](
    kind: CompareTypeSelector,
    compare: proc(data: D, oldData: D2): tuple[data: D2, changed: bool] =
      let data2 = convert(data)
      result = (data2, not equal(data2, oldData)))
  result = match(c, selector, typeSelector, actions)

proc match*[D,D2](c: Config[D], selector: string, convert: ProcTypeConverter[D,D2], equal: proc(d1, d2: D2): bool, actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeConverter` with
  ## equal procedure
  let typeSelector = TypeSelector[D,D2](
    kind: CompareTypeSelector,
    compare: proc(data: D, oldData: D2): tuple[data: D2, changed: bool] =
      let data2 = convert(data)
      result = (data2, not equal(data2, oldData)))
  result = match(c, selector, typeSelector, actions)

proc match*[X,D,D2](c: MatchConfig[X,D], selector: string, convert: ProcTypeSelectorSerial[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeSelectorSerial`.
  let typeSelector = TypeSelector[D,D2](
    kind: SerialTypeSelector,
    serial: convert)
  result = match(c, selector, typeSelector, actions)

proc match*[D,D2](c: Config[D], selector: string, convert: ProcTypeSelectorSerial[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeSelectorSerial`.
  let typeSelector = TypeSelector[D,D2](
    kind: SerialTypeSelector,
    serial: convert)
  result = match(c, selector, typeSelector, actions)

proc match*[X,D,D2](c: MatchConfig[X,D], selector: string, convert: ProcTypeSelectorCompare[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeSelectorSerial`.
  let typeSelector = TypeSelector[D,D2](
    kind: CompareTypeSelector,
    serial: convert)
  result = match(c, selector, typeSelector, actions)

proc match*[D,D2](c: Config[D], selector: string, convert: ProcTypeSelectorCompare[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeSelectorSerial`.
  let typeSelector = TypeSelector[D,D2](
    kind: CompareTypeSelector,
    serial: convert)
  result = match(c, selector, typeSelector, actions)

proc match*[X,D](c: MatchConfig[X,D], selector: string, actions: proc(x: MatchConfig[D,D]) = nil): MatchConfig[D,D] {.discardable.} =
  ## Match variant with no data refinement
  match[X,D,D](c, selector, id[D], actions)

proc match*[D](c: Config[D], selector: string, actions: proc(x: MatchConfig[D,D]) = nil): MatchConfig[D,D] {.discardable.} =
  ## Match variant for `Config` with no data refinement
  match[D,D](c, selector, id[D], actions)

proc refresh*[X,D](c: MatchConfig[X,D], refresh: ProcRefresh[D]) =
  ## Add a `ProcRefresh` callback procedure to a match. The callback is called
  ## whenever the data associated with the match changes. It can be used to
  ## update the DOM node text contents, event handlers, ...
  c.refresh.add(refresh)

proc init*[X,D](c: MatchConfig[X,D], init: ProcInit) =
  ## Add a `ProcInit` callback procedure to a match. The callback is called
  ## whenever the DOM nodes is initialized.
  c.init.add(init)

proc mount*[X,D](c: MatchConfig[X,D], conf: Config[D], node: dom.Node) =
  ## mounts a sub-component at the specified match location of a parent
  ## component. The sub-component is specified as an uncompiled configuration
  ## and DOM Node
  assert(conf != nil, "mounted configuration cannot be nil")
  assert(node != nil, "mounted node cannot be nil")
  c.mount = asInterface(compile(conf, node))

proc mount*[X,D](c: MatchConfig[X,D], comp: Component[D]) =
  ## Mounts a sub-component specified as an already compiled `Component`. The
  ## given component is cloned to ensure that the mounted component does not
  ## modify the passed instance.
  assert(comp != nil, "mounted component cannot be nil")
  c.mount = asInterface(clone(comp))

proc mount*[X,D](c: MatchConfig[X,D], comp: ComponentInterface[D]) =
  ## Mounts a sub-component specified as a `ComponentInterface` allowing to
  ## convert between generic types in case the sub-component does not have the
  ## same type as the parent component. The component is cloed to ensure the
  ## passed instance is not modified.
  assert(comp != nil, "mounted component cannot be nil")
  c.mount = comp.clone()

proc mount*[X,D,D2](c: MatchConfig[X,D], comp: Component[D2], convert: ProcTypeConverter[D,D2]) =
  ## Mounts a component and performs a type conversion between the mounted
  ## location and the mounted component. The passed component is cloned to
  ## ensure it is not modified.
  assert(comp != nil, "mounted component cannot be nil")
  c.mount = asInterface[D](clone[D2](comp), convert)

proc iter[X,D,D2](c: MatchConfig[X,D], selector: string, iter: Iterator[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  result = MatchConfig[D,D2](
    selector: selector,
    refresh: @[],
    init: @[],
    mount: nil,
    iter: true,
    iterate: iter,
    cmatches: @[])
  c.cmatches.add(result.asInterface())
  if actions != nil:
    actions(result)

proc iter[D,D2](c: Config[D], selector: string, iter: Iterator[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  result = MatchConfig[D,D2](
    selector: selector,
    refresh: @[],
    init: @[],
    mount: nil,
    iter: true,
    iterate: iter,
    cmatches: @[])
  c.cmatches.add(result.asInterface())
  if actions != nil:
    actions(result)

proc iter*[X,D,D2](c: MatchConfig[X,D], selector: string, iter: ProcIterator[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## iterates over a specified DOM node. Works just like `match` but the
  ## selected DOM node is cloned as many times as necessary to fit the number of
  ## data items provided by the given iterator.
  result = iter(c, selector, Iterator(kind: SimpleIterator, simple: iter), actions)

proc iter*[D,D2](c: Config[D], selector: string, iter: ProcIterator[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## iter variant for `Config`
  result = iter(c, selector, Iterator(kind: SimpleIterator, simple: iter), actions)

proc iter*[X,D,D2](c: MatchConfig[X,D], selector: string, iter: ProcIteratorSerial[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## iter variant for ProcIteratorSerial
  result = iter(c, selector, Iterator(kind: SerialIterator, serial: iter), actions)

proc iter*[D,D2](c: Config[D], selector: string, iter: ProcIteratorSerial[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## iter variant for ProcIteratorSerial
  result = iter(c, selector, Iterator(kind: SerialIterator, serial: iter), actions)

#
# Compile a config to a component
#

proc compile[D,D2](cfg: MatchConfig[D,D2], node: dom.Node): CompMatch[D,D2] =
  let matched_node = node.querySelector(cfg.selector)
  if matched_node == nil:
    let selector = cfg.selector
    raise newException(CompileSelectorError, &"Cannot match selector '{selector}'")

  var match = CompMatch[D,D2](
    refresh: cfg.refresh,
    init: cfg.init,
    iter: cfg.iter,
    node: matched_node)
  match.node = matched_node
  if match.iter:
    match.iterate = cfg.iterate
    match.anchor = matched_node.ownerDocument.createComment(matched_node.outerHTML)
    match.mount_template = cfg.mount
    match.match_templates = cfg.cmatches
    match.items = @[]
    matched_node.parentNode.replaceChild(match.anchor, matched_node)
  else:
    match.selectorKind = cfg.convert.kind
    case match.selectorKind
    of SerialTypeSelector:
      match.serial = 0
    else:
      discard
    match.convert = cfg.convert
    match.matches = @[]
    match.inited = false
    match.mount = nil
    if cfg.mount != nil:
      match.mount_source = cfg.mount
    else:
      for submatch in cfg.cmatches:
        match.matches.add(submatch.compile(matched_node))
  return match

proc compile[D](cfgs: seq[MatchConfigInterface[D]], node: dom.Node): seq[CompMatchInterface[D]] =
  result = @[]
  for cfg in cfgs:
    result.add(cfg.compile(node))

proc compile*[D](cfg: Config[D], node: dom.Node): Component[D] =
  ## Compiles a configuration by associating it with a DOM Node. Can raise
  ## `CompileError` in case the selectors in the configuration do not match.
  result = new(Component[D])
  result.config        = cfg.config
  result.original_node = node
  result.node          = node.cloneNode(true)

  result.config(result)
  result.matches = compile(result.cmatches, result.node)

#
# Update a component match
#

proc createIterItem[D,D2](match: CompMatch[D,D2], parentNode: dom.Node): CompMatchItem[D2] =
  ## CreateIterItem is a helper procedure to create iteration items
  var comp: ComponentInterface[D2] = nil
  var node: dom.Node
  if match.mount_template != nil:
    comp = match.mount_template.clone()
    node = comp.node()
  else:
    node = match.node.cloneNode(true)
  result = CompMatchItem[D2](
    serial: 0,
    mount: comp,
    node: node,
    matches: compile(match.match_templates, node))
  parentNode.insertBefore(node, match.anchor)

proc detach[D2](iter_item: CompMatchItem[D2], parentNode: dom.Node) =
  ## detach is a helper procedure to detach a node from an iter item
  parentNode.removeChild(iter_item.node)

proc update[D,D2](match: CompMatch[D,D2], val: D, refresh: bool) =

  if match.iter:
    var i = 0
    let parentNode = match.anchor.parentNode
    var itf: ProcIterSerial[D2]
    case match.iterate.kind
    of SimpleIterator:
      let itfSimple = match.iterate.simple(val)
      itf = proc(s: var int): tuple[ok: bool, data: D2] =
        result = itfSimple()
    of SerialIterator:
      itf = match.iterate.serial(val)

    while true:
      var serial: int = if i < len(match.items): match.items[i].serial else: 0
      var changed = refresh
      var it = itf(serial)
      if it[0] == false: break
      var item = it[1]

      var iter_item: CompMatchItem[D2]
      var inited: bool

      # Create item if needed
      if i < len(match.items):
        iter_item = match.items[i]
        inited = true
        changed = true
      else:
        iter_item = createIterItem[D,D2](match, parentNode)
        match.items.add(iter_item)
        inited = false
        if serial != iter_item.serial:
          changed = true

      # Initialize DOM Node
      if not inited:
        for initProc in match.init:
          initProc(iter_item.node)

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
    var changed = refresh
    var node = match.node
    var convertedVal: D2

    case match.convert.kind
    of SimpleTypeSelector:
      convertedVal = match.convert.simple(val)
      changed = true
    of SerialTypeSelector:
      var serial = match.serial
      convertedVal = match.convert.serial(val, serial)
      if serial != match.serial:
        changed = true
    of CompareTypeSelector:
      let res = match.convert.compare(val, match.value)
      convertedVal = res.data
      match.value = res.data
      if res.changed:
        changed = true

    # Mount the child
    if match.mount == nil and match.mount_source != nil:
      match.mount = match.mount_source.clone()
      node.parentNode.replaceChild(match.mount.node(), node)

    # Initialize DOM Node
    if not match.inited:
      for initProc in match.init:
        initProc(node)
      match.inited = true
      changed = true

    # Update mounts
    if changed and match.mount != nil:
      node = match.mount.node()
      match.mount.update(convertedVal, refresh)

    # Update the submatches
    if changed:
      for submatch in match.matches:
        submatch.update(convertedVal, refresh)

    # Refresh the node
    if changed:
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
  ## Alternative compile procedure that can be used as a method on DOM Nodes
  compile(tf, node)

proc compile*[D](d: typedesc[D], node: dom.Node, configurator: proc(c: Component[D])): Component[D] =
  ## Alternative compile procedure that creates the configuration and compiles
  ## it in one shot.
  compile(create[D](d, configurator), node)

proc clone*[D](comp: Component[D]): Component[D] =
  ## Clones a component, allows to operate them separately
  return compile(Config[D](config: comp.config), comp.original_node)

proc update*[D](t: Component[D], data: D, refresh: bool = false) =
  ## Feeds data to a compiled component, calling the refresh callbacks when
  ## needed.
  t.data = data
  for match in t.matches:
    match.update(data, refresh)

proc attach*[D](t: Component[D], target, anchor: dom.Node, data: D) =
  ## Attach a component to a parent DOM node. Insert the component as a child
  ## element of `target` and before `anchor` in the same way the `insertBefore`
  ## procedure works on DOM.
  t.update(data, refresh = true)
  target.insertBefore(t.node, anchor)

proc detach*(t: Component) =
  ## Detach a component from its parent DOM Node
  t.node.parentNode.removeChild(t.node)

#
# Interfaces
#
# CompMatchInterface: handles hiding away extra generic parameter
# MatchConfigInterface: handles hiding away extra generic parameter
#

func asInterface[D,D2](match: CompMatch[D,D2]): CompMatchInterface[D] =
  result = CompMatchInterface[D](
    update: proc(data: D, refresh: bool) = update[D,D2](match, data, refresh)
  )

func asInterface[D,D2](config: MatchConfig[D,D2]): MatchConfigInterface[D] =
  result = MatchConfigInterface[D](
    compile: proc(node: dom.Node): CompMatchInterface[D] = compile(config, node).asInterface()
  )

func asInterface*[D](comp: Component[D]): ComponentInterface[D] =
  ## Converts a component to a component interface
  result = ComponentInterface[D](
    node: proc(): dom.Node =
      comp.node,
    update: proc(data: D, refresh: bool) =
      comp.update(data, refresh),
    clone: (proc(): ComponentInterface[D] =
      asInterface(clone(comp))))

func asInterface*[D,D2](comp: Component[D2], convert: ProcTypeConverter[D,D2]): ComponentInterface[D] =
  ## Converts a component to a component interface and convert its type
  result = ComponentInterface[D](
    node: proc(): dom.Node =
      comp.node,
    update: proc(data: D, refresh: bool) =
      comp.update(convert(data), refresh),
    clone: (proc(): ComponentInterface[D] =
      asInterface(clone(comp), convert)))

proc late*[D](lateComp: proc(): Component[D]): ComponentInterface[D] =
  ## Returns a component interface from a component where the component is not
  ## there yet. This can be used to recursively mount a component into itself.
  ## At compile time, the `lateComp` proc is going to be called and will resolve
  ## into a real component.
  ##
  ## If when called, `lateComp` cannot resolve to a non nil component, an
  ## exception of type CompileLateError will be raised.
  var comp: Component[D] = nil

  proc resolveComp() :Component[D] =
    if comp == nil:
      var late = lateComp()
      if late != nil:
        raise newException(CompileLateError, &"Late component not resolved in time")
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
# Helper procs
#

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

proc eql*[T](s1, s2: T): bool =
  mixin `==`
  result = (s1 == s2)
