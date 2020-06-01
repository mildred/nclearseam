import nclearseam
import nclearseam/util
import nclearseam/fetchutil
import nclearseam/dom
import nclearseam/registry
import jsconsole
import jsffi
import json

type
  Settings* = ref object
    cubeprice: int

var SettingsComponent*: ComponentInterface[Settings]

components.declare(SettingsComponent, fetchTemplate("settings.html", "template", css = true)) do(node: dom.Node) -> Component[Settings]:
  return compile(Settings, node) do(c: auto):
    c.match("[name=cubeprice]", c.access->cubeprice, eql).refresh(bindValue(int))
    c.match(".cubeprice", c.access->cubeprice, eql).refresh(setText(int))

# TODO:
#
# Comp|CompMatch -> field -> field
# produces: proc(update: bool, val: T = init(T)): T
#
# Taken by the match proc, it can be used to init/refresh values or mount
# subcomponents. Reading the cata is calling the proc with (false)
#
# If the refresh wants to modify the data, it calls the proc with
# (true, new_val). At that moment, the component is triggered for an update
#
# If a component updates, the parent component will be notified that the valus
# has changed too using a similar mechanism and will update ..? everything ..?
#
# When a value change that way, an event object should record which value was
# modified, and when update happens, this info should be used to decide if a
# CompMatch should be updated based on this. For example the pointers from the
# root data object up to the changed leaf value should be recorded, and if the
# update happens along this tree, the update should proceed. else, the update
# should stop as it is about an unmodified tree

