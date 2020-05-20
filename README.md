nim-svelte
==========

This is a templating library targetting javascript in browsers. The aim is to
keep it just a library, not make it into a full framework, and to get out of
your way. It also aims to be fast and avoids complexities of Virtual DOMs. It
gets inspiration from [Svelte.js][sveltejs] for that well as [Weld][weld],
[PureJS][purejs] and my own [Clearseam][clearseam] for the syntax.

Key features:

- lightweight, library only
- be fast, avoids Virtual DOM by patching only the required part of the browser
  DOM when necessary. Uses the same technique as [Svelte.js][sveltejs].
- No extra syntax to learn, uses plain HTML `<template>` elements with a mapping
  between the dataset and the elements that you provide
- No extra selectors to learn, uses plain CSS and Nim language for the mapping
- Full control over what you do to the DOM nodes (HTML attributes, Javascript
  properties, event handlers or anything you can think of)

Rationale is explained in [`docs/svelte_with_nim.md`](docs/svelte_with_nim.html).

Warning: this is a very young project, use at your own risks

Example
-------

Templating is always the combinaison of three factors: the HTML markup, the data
(generally JSON, but it's generic) and the mapping.

You can also [view live examples](samples/):

- [Sample 1](samples/sample1.html): basics and iteration
- [Sample 2](samples/sample2.html): mounting other components
- [Sample 3](samples/sample3.html): using something else than JSON for data sets

**Important Node:** This is still a work in progress, and while working on it,
there is a few areas that do not work as documented yet:

- sample 1 and 2 might not work
- using only JsonNode as dataset is deprecated, instead use your own structured
  data as shown in sample 3

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

### Mounting components

```html
<template>
  <div class="placeholder"></div>
</template>
```

```json
{
  "placeholder-data": {}
}
```

```nim
var t = create(JsonNode) do(t: auto):
  t.match("div.placeholder", get("placeholder-data")) do(placeholder: auto):
    placeholder.mount(other_component)
```

Use it
------

This is very experimental still, use at your own risks.

- see examples, you can rebuild samples with:

    ```shell
    nim js samples/sample1
    ```

- copy a sample elsewhere and build it the same way

- try it in a browser by spawining a simple HTTP server:

    ```shell
    python -m http.server 8000
    xdg-open http://localhost:8000/samples/sample1.html
    ```

[sveltejs]: http://svelte.dev
[weld]: https://github.com/tmpvar/weld
[purejs]: https://pure-js.com/
[clearseam]: https://github.com/mildred/clearseam
