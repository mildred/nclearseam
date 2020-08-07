import sequtils
import strformat
import system
#import jsconsole
import strutils
import ./nclearseam/dom

type
  BindError* = object of CatchableError ##\
  ## Error raised when updating data is tried on read-only template

  CompileError* = object of CatchableError ##\
  ## Parent type for all errors

  CompileSelectorError* = object of CompileError ## \
  ## Type for an object that can be raised in case there is a problem \
  ## with the template configuration such as a CSS selector not matching the \
  ## given template DOM Node

  CompileLateError* = object of CompileError ## \
  ## Represents an error wen a late binding fails.

  CannotSetError* = object of CatchableError ## \
  ## Represents an error where a callback tries to update a dataset that is not
  ## modifyable

  ProcMatchConfig*[D1,D2] = proc(c: MatchConfig[D1,D2]) ## \
  ## procedure callback that is called upon compilation to configure a
  ## component match

  ProcInit* = proc(node: dom.Node) ## \
  ## Procedure callback that is called whenever a part of a template needs to \
  ## be initialized (such as installing event handlers)

  ProcRefreshSimple*[D] = proc(node: dom.Node, data: D) ## \
  ## Procedure callback that is called whenever a part of a template needs to \
  ## be refreshed on data change.

  DataPath* = seq[string] ##\
  ## Represents a path to a part of a dataset, used for partial updates

  ProcSet[D] = proc(newValue: D, path: DataPath = @[]) ## \
  ## procedure used to update a value of a given type. provides a path
  ## representing the subset of the data that actually changed and that needs
  ## update. Other values will not update. Default path is an empty path to
  ## signify that all the data changed

  RefreshEvent*[D] = ref object
    ## Represents a refresh event passed to the refresh procedure
    ##
    ## ``node`` is the DOM node to refresh
    ## ``data`` is the dataset to refresh with
    ## ``init`` is true if this is the first refresh event for the node
    ## ``set``  can be called to update the value
    node*: dom.Node
    data*: D
    init*: bool
    set*:  ProcSet[D]
    before*: bool
    skip*: bool

  ProcRefresh*[D] = proc(e: RefreshEvent[D]) ## \
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

  TypeSelector*[D1,D2] = ref object
    ## Interface object that given a larger object of type D1 can refine it to
    ## type D2 which represents a subset of D1. ``id`` represents the unique
    ## path from D1 to D2, and the ``set`` procedure allows to update D1.
    ##
    ## When the data changes (through ``set``), the engine knows which id
    ## changed and puts it in an update list. The template is then updated only
    ## on the paths that were modified.
    get*: proc(data: D1): D2
    set*: proc(data: var D1, value: D2)
    id*:  DataPath

  TypeSelectorKind = enum
    SimpleTypeSelector,
    SerialTypeSelector,
    CompareTypeSelector,
    ObjectTypeSelector

  MultiTypeSelector[D1,D2] = object
    case kind: TypeSelectorKind
    of SimpleTypeSelector:
      simple: ProcTypeConverter[D1,D2]
    of SerialTypeSelector:
      serial: ProcTypeSelectorSerial[D1,D2]
    of CompareTypeSelector:
      compare: ProcTypeSelectorCompare[D1,D2]
    of ObjectTypeSelector:
      obj: TypeSelector[D1,D2]
      eql: proc(v1, v2: D2): bool

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

  ProcIterTypeSelector*[D1,D2] = proc(): TypeSelector[D1,D2]
  ProcIteratorTypeSelector*[D1,D2] = proc(d: D1): ProcIterTypeSelector[D1,D2]

  IteratorKind* = enum
    SimpleIterator,
    SerialIterator,
    TypeSelectorIterator

  Iterator*[D1,D2] = object
    case kind: IteratorKind
    of SimpleIterator:
      simple: ProcIterator[D1,D2]
    of SerialIterator:
      serial: ProcIteratorSerial[D1,D2]
    of TypeSelectorIterator:
      selector: ProcIteratorTypeSelector[D1,D2]

  IterItem[D] = ref object
    updateComp:  proc(comp: ComponentInterface[D], refresh: bool)
    updateMatch: proc(m: CompMatch[D], refresh: bool)
    refresh:     proc(refreshProc: ProcRefresh[D], node: dom.Node)
    next:        proc(): IterItem[D]
  ProcIterInternal[D] = proc(data: D): IterItem[D]

  UpdateSet* = ref object
    ## Represents a list of data paths which are modified
    paths: seq[DataPath]

  #
  # Config: Global component configuration
  #

  MatchConfig*[D,D2] = ref object of RootObj
    ## Part of a template configuration, related to particular sub-section \
    ## represented by a CSS selector.
    selector: string
    refresh: seq[ProcRefresh[D2]]
    refresh_before: seq[ProcRefresh[D2]]
    init: seq[ProcInit]
    cmatches: seq[MatchConfigInterface[D2]]
    mount: ComponentInterface[D2]
    case iter: bool
    of false:
      convert: MultiTypeSelector[D,D2]
    of true:
      iterate: Iterator[D,D2]

  MatchConfigInterface[D] = ref object
    compile: proc(node: dom.Node): seq[CompMatchInterface[D]]

  Config*[D] = ref object of MatchConfig[D,D]
    ## Represents a template configuration, not yet associated with a DOM Node
    config: ProcMatchConfig[D,D]

  #
  # Component: Global component object
  #

  CompMatch[D,D2] = ref object
    # CompMatch: handle association between DOM and a selector match
    refresh: seq[ProcRefresh[D2]]
    refresh_before: seq[ProcRefresh[D2]]
    init: seq[ProcInit]
    node: dom.Node
    case iter: bool
    of false:
      case selectorKind: TypeSelectorKind
      of SerialTypeSelector:
        serial: int
      of CompareTypeSelector, ObjectTypeSelector:
        value: D2
      else: discard
      convert: MultiTypeSelector[D,D2]
      mount_source: ComponentInterface[D2]
      mount: ComponentInterface[D2]
      matches: seq[CompMatchInterface[D2]]
      inited: bool
      skip: bool
    of true:
      iterate: Iterator[D,D2]
      mount_template: ComponentInterface[D2]
      match_templates: seq[MatchConfigInterface[D2]]
      items: seq[CompMatchItem[D2]]
      anchor: dom.Node

  CompMatchInterface[D] = ref object
    update: proc(data: D, set: ProcSet[D], refreshList: UpdateSet)


  CompMatchItem[D2] = ref object
    # CompMatchItem: handle iterations
    serial: int
    node: dom.Node
    matches: seq[CompMatchInterface[D2]]
    mount: ComponentInterface[D2]
    skip: bool

  Component*[D] = ref object
    ## Represents an instanciated template, a `Config` that has been compiled \
    ## with a DOM node.
    cmatches: seq[CompMatch[D,D]]
    config: ProcMatchConfig[D,D]
    convert: MultiTypeSelector[D,D]
    original_node: dom.Node
    node: dom.Node
    data*: D

  ComponentInterface*[D] = ref object
    ## Wrapper around a `Component`, allowing the generic type to be converted.
    node*:   proc(): dom.Node
    update*: proc(data: D, set: ProcSet[D], refreshList: UpdateSet)
    clone*:  proc(): ComponentInterface[D]

#
# Forward declaration interface conversion
#

func asInterface[D,D2](config: MatchConfig[D,D2]): MatchConfigInterface[D]
func asInterface[D,D2](match: CompMatch[D,D2]): CompMatchInterface[D]
func asInterface*[D](comp: Component[D]): ComponentInterface[D]
func asInterface*[D,D2](comp: Component[D2], convert: TypeSelector[D,D2]): ComponentInterface[D]

#
# Forward declaration of the public API
#

proc compile*[D](d: typedesc[D], node: dom.Node, configurator: ProcMatchConfig[D,D], equal: proc(v1, v2: D): bool = nil): Component[D]
proc clone*[D](comp: Component[D]): Component[D]

#
# Utils
#

proc id[D](data: D): D = data

proc idTypeSelector[D](): TypeSelector[D,D] =
  return TypeSelector[D,D](
    get: proc(data: D): D = data,
    set: proc(data: var D, value: D) = data = value,
    id:  @[])

proc idMultiTypeSelector[D](equal: proc(a, b: D): bool): MultiTypeSelector[D,D] =
  return MultiTypeSelector[D,D](
    kind: ObjectTypeSelector,
    eql:  equal,
    obj:  idTypeSelector[D]())

proc is_changed*(set: UpdateSet): bool =
  ## Returns true if the update set is telling that the current node needs to
  ## update
  result = (set == nil or set.paths.len > 0)

proc walk*(set: UpdateSet, path: DataPath): UpdateSet =
  ## Walk `path` and remove `path` prefix from all paths in ``set``. If a path
  ## in ``set`` does not start with the given path, it is discarded
  if set == nil: return nil
  result = UpdateSet(paths: @[])
  for oldPath in set.paths:
    block createNewPath:
      var newPath: DataPath = @[]
      if oldPath.len < path.len:
        break createNewPath
      for i in 0 .. (path.len - 1):
        if i >= oldPath.len:
          break
        if path[i] != oldPath[i]:
          break createNewPath
      if oldPath.len > path.len:
        newPath = oldPath[(path.len)..^1]
      result.paths.add(newPath)

let emptyDataPath*: DataPath = @[]

let refreshAll*: UpdateSet = UpdateSet(
  paths: @[ emptyDataPath ]
)

proc sub[D1,D2](ts: TypeSelector[D1,D2], val: var D1, setVal: ProcSet[D1], update: proc(refreshList: UpdateSet)): ProcSet[D2] =
  if setVal == nil and update == nil:
    return nil
  result = proc(newValue: D2, changedPath: DataPath) =
    ts.set(val, newValue)
    let newPath = ts.id & changedPath
    if setVal != nil:
      setVal(val, newPath)
    elif update != nil:
      #console.log("Update %s", $newPath)
      update(UpdateSet(paths: @[newPath]))

proc `$`*(path: DataPath): string =
  path.join("->")

proc `$`*(refreshList: UpdateSet): string =
  refreshList.paths.join(", ")

#
# Configuration DSL
#
# create:  creates a new config
# match:   match an element using a selector and allows to manipulate it
# refresh: calls a callback each time the element needs refreshing
# mount:   mount another component at the element location
# iter:    duplicate the element using a collection iterator
#

proc create*[D](equal: proc(v1,v2: D): bool = nil): Config[D] =
  ## Create a new empty configuration. Takes a dataset type as first argument
  return Config[D](
    iter: false,
    convert: idMultiTypeSelector[D](equal))

proc create*[D](d: typedesc[D], config: ProcMatchConfig[D,D], equal: proc(v1,v2: D): bool = nil): Config[D] =
  ## Create a new empty configuration but allows to pass a procedure to modify
  ## the configuration

  #runnableExamples:
  #  ## Hello World configuration
  #  type HelloName = ref object
  #    name: string

  #  let tmpl = create(HelloName) do(c: auto):
  #    c.match(".name").refresh do(node: dom.Node, data: HelloName):
  #      node.textContents = data.name

  return Config[D](
    iter: false,
    convert: idMultiTypeSelector[D](equal),
    config: config)

proc match[X,D,D2](c: MatchConfig[X,D], selector: string, convert: MultiTypeSelector[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Declares a sub-match. The selector is run to find the DOM node that the
  ## sub-match will modify, and the convert procedure allows to refine the
  ## dataset when the sub-match only needs a portion of this dataset. The
  ## optional actions procedure can be used to further configure the sub-match.
  result = MatchConfig[D,D2](
    selector: selector,
    refresh: @[],
    refresh_before: @[],
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
  let typeSelector = MultiTypeSelector[D,D2](
    kind: SimpleTypeSelector,
    simple: convert)
  result = match(c, selector, typeSelector, actions)

proc match*[X,D,D2](c: MatchConfig[X,D], selector: string, convert: TypeSelector[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeConverter`.
  let typeSelector = MultiTypeSelector[D,D2](
    kind: ObjectTypeSelector,
    obj: convert)
  result = match(c, selector, typeSelector, actions)

proc match*[X,D,D2](c: MatchConfig[X,D], selector: string, convert: TypeSelector[D,D2], equal: proc(d1, d2: D2): bool, actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeConverter`.
  let typeSelector = MultiTypeSelector[D,D2](
    kind: ObjectTypeSelector,
    obj: convert,
    eql: equal)
  result = match(c, selector, typeSelector, actions)

proc match*[X,D,D2](c: MatchConfig[X,D], convert: TypeSelector[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeConverter` and
  ## without selector
  let typeSelector = MultiTypeSelector[D,D2](
    kind: ObjectTypeSelector,
    obj: convert)
  result = match(c, "", typeSelector, actions)

proc match*[X,D,D2](c: MatchConfig[X,D], convert: TypeSelector[D,D2], equal: proc(d1, d2: D2): bool, actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeConverter` and
  ## without selector
  let typeSelector = MultiTypeSelector[D,D2](
    kind: ObjectTypeSelector,
    obj: convert,
    eql: equal)
  result = match(c, "", typeSelector, actions)

proc match*[X,D,D2](c: MatchConfig[X,D], selector: string, convert: ProcTypeConverter[D,D2], equal: proc(d1, d2: D2): bool, actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeConverter` with
  ## equal procedure
  let typeSelector = MultiTypeSelector[D,D2](
    kind: CompareTypeSelector,
    compare: proc(data: D, oldData: D2): tuple[data: D2, changed: bool] =
      let data2 = convert(data)
      result = (data2, not equal(data2, oldData)))
  result = match(c, selector, typeSelector, actions)

proc match*[X,D,D2](c: MatchConfig[X,D], selector: string, convert: ProcTypeSelectorSerial[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeSelectorSerial`.
  let typeSelector = MultiTypeSelector[D,D2](
    kind: SerialTypeSelector,
    serial: convert)
  result = match(c, selector, typeSelector, actions)

proc match*[X,D,D2](c: MatchConfig[X,D], selector: string, convert: ProcTypeSelectorCompare[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## Match variant with convert procedure as simple `ProcTypeSelectorSerial`.
  let typeSelector = MultiTypeSelector[D,D2](
    kind: CompareTypeSelector,
    serial: convert)
  result = match(c, selector, typeSelector, actions)

proc match*[X,D](c: MatchConfig[X,D], selector: string, actions: proc(x: MatchConfig[D,D]) = nil): MatchConfig[D,D] {.discardable.} =
  ## Match variant with no data refinement
  match[X,D,D](c, selector, idTypeSelector[D](), actions)

proc refresh*[X,D](c: MatchConfig[X,D], refresh: ProcRefreshSimple[D], before, after: bool = false) =
  ## Add a `ProcRefresh` callback procedure to a match. The callback is called
  ## whenever the data associated with the match changes. It can be used to
  ## update the DOM node text contents, event handlers, ...
  ## If before is true, then the callback is called before sub-matches are
  ## refreshed and can be used to skip refreshing them
  if before:
    c.refresh_before.add(proc(re: RefreshEvent[D]) = refresh(re.node, re.data))
  if after or not before:
    c.refresh.add(proc(re: RefreshEvent[D]) = refresh(re.node, re.data))

proc refresh*[X,D](c: MatchConfig[X,D], refresh: ProcRefresh[D], before, after: bool = false) =
  ## Add a `ProcRefresh` callback procedure to a match. The callback is called
  ## whenever the data associated with the match changes. It can be used to
  ## update the DOM node text contents, event handlers, ...
  if c.iter:
    case c.iterate.kind
    of SimpleIterator:
      raise newException(BindError, &"refresh with RefreshEvent is forbidden when iterator (simple) does not allow updates")
    of SerialIterator:
      raise newException(BindError, &"refresh with RefreshEvent is forbidden when iterator (serial) does not allow updates")
    of TypeSelectorIterator:
      discard
  else:
    case c.convert.kind
    of SimpleTypeSelector:
      raise newException(BindError, &"refresh with RefreshEvent is forbidden when type selector (simple) does not allow updates")
    of SerialTypeSelector:
      raise newException(BindError, &"refresh with RefreshEvent is forbidden when type selector (serial) does not allow updates")
    of CompareTypeSelector:
      raise newException(BindError, &"refresh with RefreshEvent is forbidden when type selector (compare) does not allow updates")
    of ObjectTypeSelector:
      discard
  if before:
    c.refresh_before.add(refresh)
  if after or not before:
    c.refresh.add(refresh)

proc init*[X,D](c: MatchConfig[X,D], init: ProcInit) =
  ## Add a `ProcInit` callback procedure to a match. The callback is called
  ## whenever the DOM nodes is initialized.
  c.init.add(init)

proc mount*[X,D](c: MatchConfig[X,D], conf: Config[D] | Component[D], node: dom.Node) =
  ## mounts a sub-component at the specified match location of a parent
  ## component. The sub-component is specified as an uncompiled configuration
  ## and DOM Node
  assert(conf != nil, "mounted configuration cannot be nil")
  assert(node != nil, "mounted node cannot be nil")
  c.mount = asInterface(compile(node, conf))

proc mount*[X,D](c: MatchConfig[X,D], comp: Component[D]) =
  ## Mounts a sub-component specified as an already compiled `Component`. The
  ## given component is cloned to ensure that the mounted component does not
  ## modify the passed instance.
  assert(comp != nil, "mounted component cannot be nil (use late() to perform late component binding)")
  c.mount = asInterface(comp)

proc mount*[X,D](c: MatchConfig[X,D], comp: ComponentInterface[D]) =
  ## Mounts a sub-component specified as a `ComponentInterface` allowing to
  ## convert between generic types in case the sub-component does not have the
  ## same type as the parent component. The component is cloed to ensure the
  ## passed instance is not modified.
  assert(comp != nil, "mounted component cannot be nil")
  c.mount = comp

proc mount*[X,D,D2](c: MatchConfig[X,D], comp: Component[D2], convert: TypeSelector[D,D2]) =
  ## Mounts a component and performs a type conversion between the mounted
  ## location and the mounted component. The passed component is cloned to
  ## ensure it is not modified.
  assert(comp != nil, "mounted component cannot be nil (use late() to perform late component binding)")
  c.mount = asInterface[D](comp, convert)

proc mount*[X,D,D2](c: MatchConfig[X,D], comp: ComponentInterface[D2], convert: TypeSelector[D,D2]) =
  ## Mounts a component and performs a type conversion between the mounted
  ## location and the mounted component. The passed component is cloned to
  ## ensure it is not modified.
  assert(comp != nil, "mounted component cannot be nil")
  c.mount = asInterface[D](comp, convert)

proc iter[X,D,D2](c: MatchConfig[X,D], selector: string, iter: Iterator[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  result = MatchConfig[D,D2](
    selector: selector,
    refresh: @[],
    refresh_before: @[],
    init: @[],
    mount: nil,
    iter: true,
    iterate: iter,
    cmatches: @[])
  c.cmatches.add(result.asInterface())
  if actions != nil:
    actions(result)

proc iter*[X,D,D2](c: MatchConfig[X,D], selector: string, it: ProcIterator[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## iterates over a specified DOM node. Works just like `match` but the
  ## selected DOM node is cloned as many times as necessary to fit the number of
  ## data items provided by the given iterator.
  result = iter(c, selector, Iterator[D,D2](kind: SimpleIterator, simple: it), actions)

proc iter*[X,D,D2](c: MatchConfig[X,D], selector: string, it: ProcIteratorSerial[D,D2], actions: proc(x: MatchConfig[D,D2]) = nil): MatchConfig[D,D2] {.discardable.} =
  ## iter variant for ProcIteratorSerial
  result = iter(c, selector, Iterator[D,D2](kind: SerialIterator, serial: it), actions)

#
# Compile a config to a component
#

proc compile[D,D2](cfg: MatchConfig[D,D2], node: dom.Node): seq[CompMatch[D,D2]] =
  result = @[]
  let matched_nodes = if cfg.selector == "": @[cast[Element](node)] else: node.querySelectorAll(cfg.selector)
  if matched_nodes.len == 0:
    let selector = cfg.selector
    raise newException(CompileSelectorError, &"Cannot match selector '{selector}'")

  for matched_node in matched_nodes:
    var match = CompMatch[D,D2](
      refresh: cfg.refresh,
      refresh_before: cfg.refresh_before,
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
    result.add(match)

proc compile[D](cfgs: seq[MatchConfigInterface[D]], node: dom.Node): seq[CompMatchInterface[D]] =
  result = @[]
  for cfg in cfgs:
    result.add(cfg.compile(node))

proc compile*[D](d: typedesc[D], node: dom.Node, configurator: ProcMatchConfig[D,D], equal: proc(v1,v2: D): bool = nil): Component[D] =
  ## Alternative compile procedure that creates the configuration and compiles
  ## it in one shot.
  assert node != nil
  let cfg = create(D, configurator, equal)
  cfg.config(cfg)

  result = new(Component[D])
  result.config        = configurator
  result.convert       = idMultiTypeSelector(equal)
  result.original_node = node
  result.node          = node.cloneNode(true)
  result.cmatches      = compile(cfg, result.node)


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

proc update[D,D2](match: CompMatch[D,D2], initVal: D, setVal: ProcSet[D], refreshList: UpdateSet) =
  assert(setVal != nil)
  var val = initVal

  if match.iter:
    var i = 0
    let parentNode = match.anchor.parentNode
    var subList: UpdateSet
    var it_simple: ProcIter[D2]
    var it_serial: ProcIterSerial[D2]
    var it_select: ProcIterTypeSelector[D,D2]
    case match.iterate.kind
    of SimpleIterator:
      it_simple = match.iterate.simple(val)
    of SerialIterator:
      it_serial = match.iterate.serial(val)
    of TypeSelectorIterator:
      it_select = match.iterate.selector(val)

    while true:
      var serial: int = if i < len(match.items): match.items[i].serial else: 0
      var changed = refreshList.is_changed()
      var item: D2
      var set: ProcSet[D2] = nil #proc(newValue: D2) = raise newException(BindError, &"Cannot change data, type-selector is read-only")
      case match.iterate.kind
      of SimpleIterator:
        var it = it_simple()
        if it[0] == false: break
        item = it[1]
        set = proc(newValue: D2, path: DataPath = @[]) =
          raise newException(CannotSetError, &"Cannot update data with SimpleIterator")
        #console.log("nclearseam.update(iter, changed=%o) using %o", changed, item)
      of SerialIterator:
        var it = it_serial(serial)
        if it[0] == false: break
        item = it[1]
        set = proc(newValue: D2, path: DataPath = @[]) =
          raise newException(CannotSetError, &"Cannot update data with SerialIterator")
        #console.log("nclearseam.update(iter, changed=%o) using %o", changed, item)
      of TypeSelectorIterator:
        var it = it_select()
        if it == nil: break
        item = it.get(val)
        set = it.sub(val, setVal) do(refreshList: UpdateSet):
          update(match, val, setVal, refreshList)
        subList = refreshList.walk(it.id)
        changed = subList.is_changed()
        #console.log("nclearseam.update(iter, changed=%o, id=%o) using %o", changed, $it.id, item)

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

      # Refresh the node
      var e = RefreshEvent[D2](
        node:   iter_item.node,
        data:   item,
        init:   not inited,
        set:    set,
        before: true,
        skip:   iter_item.skip)
      for refreshProc in match.refresh_before:
        refreshProc(e)
        iter_item.skip = e.skip

      # Refresh mounts
      if iter_item.mount != nil and not iter_item.skip:
        iter_item.mount.update(item, set, subList)

      # Refresh the submatches
      if not iter_item.skip:
        for submatch in iter_item.matches:
          submatch.update(item, set, subList)

      # Refresh the node
      e = RefreshEvent[D2](
        node:   iter_item.node,
        data:   item,
        init:   not inited,
        set:    set,
        before: false,
        skip:   iter_item.skip)
      for refreshProc in match.refresh:
        refreshProc(e)
        iter_item.skip = e.skip

      i = i + 1

    # Remove extra items if there is any because the list shrinked
    while i < len(match.items):
      detach(pop(match.items), parentNode)
  else:
    var changed = refreshList.is_changed()
    var subList: UpdateSet
    var node = match.node
    var convertedVal: D2
    var set: ProcSet[D2] = nil #proc(newValue: D2) = raise newException(BindError, &"Cannot change data, type-selector is read-only")

    case match.convert.kind
    of SimpleTypeSelector:
      convertedVal = match.convert.simple(val)
      changed = true
      #console.log("nclearseam.update(match, changed=%o) with %o", changed, convertedVal)
    of SerialTypeSelector:
      var serial = match.serial
      convertedVal = match.convert.serial(val, serial)
      if serial != match.serial:
        changed = true
      #console.log("nclearseam.update(match, changed=%o) with %o", changed, convertedVal)
    of CompareTypeSelector:
      let res = match.convert.compare(val, match.value)
      convertedVal = res.data
      match.value = res.data
      if res.changed:
        changed = true
      #console.log("nclearseam.update(match, changed=%o) with %o", changed, convertedVal)
    of ObjectTypeSelector:
      let obj = match.convert.obj
      convertedVal = obj.get(val)
      subList = refreshList.walk(obj.id)
      changed = subList.is_changed()
      if changed and match.convert.eql != nil:
        changed = not match.convert.eql(convertedVal, match.value)
      set = obj.sub(val, setVal) do(refreshList: UpdateSet):
        update(match, val, setVal, refreshList)
      #console.log("nclearseam.update(match, changed=%o, id=%o) with %o", changed, $obj.id, convertedVal)

    # Mount the child
    if match.mount == nil and match.mount_source != nil:
      match.mount = match.mount_source.clone()
      node.parentNode.replaceChild(match.mount.node(), node)

    # Initialize DOM Node
    let inited = match.inited
    if not inited:
      for initProc in match.init:
        initProc(node)
      match.inited = true
      changed = true

    if changed:
      let e = RefreshEvent[D2](
        node:   node,
        data:   convertedVal,
        init:   not inited,
        set:    set,
        before: true,
        skip:   match.skip)
      for refreshProc in match.refresh_before:
        refreshProc(e)
        match.skip = e.skip

    # Update mounts
    if changed and match.mount != nil and not match.skip:
      node = match.mount.node()
      match.mount.update(convertedVal, set, subList)

    # Update the submatches
    if changed and not match.skip:
      for submatch in match.matches:
        submatch.update(convertedVal, set, subList)

    if changed:
      let e = RefreshEvent[D2](
        node:   node,
        data:   convertedVal,
        init:   not inited,
        set:    set,
        before: false,
        skip:   match.skip)
      for refreshProc in match.refresh:
        refreshProc(e)
        match.skip = e.skip

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
  assert node != nil
  compile(tf, node)

proc compile*[D](cfg: Config[D] | Component[D], node: dom.Node): Component[D] =
  ## Compiles a configuration by associating it with a DOM Node. Can raise
  ## `CompileError` in case the selectors in the configuration do not match.
  compile(D, node, cfg.config, cfg.convert.eql)

proc clone*[D](comp: Component[D]): Component[D] =
  ## Clones a component, allows to operate them separately
  return compile(D, comp.original_node, comp.config, comp.convert.eql)

proc update*[D](t: Component[D], initVal: D, setVal: ProcSet[D] = nil, refreshList: UpdateSet = nil) =
  ## Feeds data to a compiled component, calling the refresh callbacks when
  ## needed.
  t.data = initVal

  proc upd(refreshList: UpdateSet)
  proc set(newVal: D, changedPath: DataPath) =
    t.data = newVal
    if setVal != nil:
      setVal(newVal, changedPath)
    else:
      upd(UpdateSet(paths: @[changedPath]))

  proc upd(refreshList: UpdateSet) =
    for match in t.cmatches:
      match.update(t.data, set, refreshList)

  upd(refreshList)

proc attach*[D](t: Component[D], target, anchor: dom.Node, data: D, set: ProcSet[D] = nil) =
  ## Attach a component to a parent DOM node. Insert the component as a child
  ## element of `target` and before `anchor` in the same way the `insertBefore`
  ## procedure works on DOM.
  t.update(data, set, refreshAll)
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
    update: proc(data: D, set: ProcSet[D], refreshList: UpdateSet) = update[D,D2](match, data, set, refreshList)
  )

func asInterface[D,D2](config: MatchConfig[D,D2]): MatchConfigInterface[D] =
  result = MatchConfigInterface[D](
    compile: (proc(node: dom.Node): seq[CompMatchInterface[D]] =
      result = @[]
      for comp_match in compile(config, node):
        result.add(comp_match.asInterface()))
  )

func asInterface*[D](comp: Component[D]): ComponentInterface[D] =
  ## Converts a component to a component interface
  result = ComponentInterface[D](
    node: proc(): dom.Node =
      comp.node,
    update: proc(data: D, set: ProcSet[D], refreshList: UpdateSet) =
      comp.update(data, set, refreshList),
    clone: (proc(): ComponentInterface[D] =
      asInterface(clone(comp))))

func asInterface*[D,D2](comp: Component[D2], convert: TypeSelector[D,D2]): ComponentInterface[D] =
  ## Converts a component to a component interface and convert its type
  result = ComponentInterface[D](
    node: proc(): dom.Node =
      comp.node,
    update: proc(initVal: D, setVal: ProcSet[D], refreshList: UpdateSet) =
      var val = initVal
      comp.update(convert.get(val), convert.sub(val, setVal, nil), refreshList.walk(convert.id)),
    clone: (proc(): ComponentInterface[D] =
      asInterface(clone(comp), convert)))

func asInterface*[D,D2](comp: ComponentInterface[D2], convert: TypeSelector[D,D2]): ComponentInterface[D] =
  ## Converts a component to a component interface and convert its type
  result = ComponentInterface[D](
    node: proc(): dom.Node =
      comp.node(),
    update: proc(initVal: D, setVal: ProcSet[D], refreshList: UpdateSet) =
      var val = initVal
      comp.update(convert.get(val), convert.sub(val, setVal, nil), refreshList.walk(convert.id)),
    clone: (proc(): ComponentInterface[D] =
      asInterface(comp.clone(), convert)))

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
      if late == nil:
        raise newException(CompileLateError, &"Late component not resolved in time")
      comp = late
    return comp

  proc create(): ComponentInterface[D] =
    result = ComponentInterface[D](
      node: proc(): dom.Node =
        resolveComp().node,
      update: proc(data: D, set: ProcSet[D], refreshList: UpdateSet) =
        resolveComp().update(data, set, refreshList),
      clone: proc(): ComponentInterface[D] =
        asInterface(resolveComp().clone())
    )

  result = create()
