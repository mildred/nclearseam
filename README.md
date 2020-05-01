nim-svelte
==========

This is a templating library targetting javascript in browsers. The aim is to
keep it just a library, not make it into a full framework, and to get out of
your way. It also aims to be fast and avoids complexities of Virtual DOMs. It
gets inspiration from [Svelte.js][sveltejs] for thats well as [Weld][weld] and
[PureJS][purejs] for the syntax.

Key features:

- lightweight, library only
- be fast, avoids Virtual DOM by patching only the required part of the browser
  DOM when necessary. Uses the same technique as [Svelte.js][sveltejs].
- No extra syntax to learn, uses plain HTML `<template>` elements with a mapping
  between the dataset and the elements that you provide
- No extra selectors to learn, uses plain CSS and Nim language for the mapping
- Full control over what you do to the DOM nodes (HTML attributes, Javascript
  properties, event handlers or anything you can think of)

Rationale is explained in [`doc/svelte_with_nim.md`](doc/svelte_with_nim.md).

Warning: this is a very young project, use at your own risks

Example
-------

Templating is always the combinaison of three factors: the HTML markup, the data
(generally JSON, but it's generic) and the mapping.

### Hello World

```html
<template>
  <h1>hello <span class="name"></span>!</h1>
</template>
```

```json
{
  "name": "John"
}
```

```nim
var t = create(JsonNode) do(t: auto):
  t.match("h1 .name", get("name")) do(node: dom.Node, data: JsonNode):
    node.textContent = data.getStr()
```

### Iterations

```html
<template>
  <ul>
    <li>item: <span class="name"></span></li>
  </ul>
</template>
```

```json
{
  "items": ["Apple", "Orange", "Kiwi"]
}
```

```nim
var t = create(JsonNode) do(t: auto):
  t.iter("ul li", get("items")) do(item: auto):
    item.match(".name", get()) do(node: dom.Node, data: JsonNode):
      node.textContent = $data
```


[sveltejs]: http://svelte.dev
[weld]: https://github.com/tmpvar/weld
[purejs]: https://pure-js.com/
