# Testing

Run everything (luacheck, forever-lint and busted, in WSL) from Git Bash:

```sh
bash scripts/test.sh
```

## Layout specs

`tests/OrdaenCore/layout_spec.lua` drives the engine directly with a fake measurer: every character is 6 units wide,
a line is 12 high, text wraps at word boundaries. Expected sizes are then plain arithmetic.

```lua
it("wraps text that is wider than the block's maxWidth, and the row grows", function()
  local block = { maxWidth = 60, { text = "one two three four" } } -- 18 chars = 108
  local r = Layout.Run(block, nil, ctx())
  assert.equals(60, r.width)
  assert.equals(2 * LINE, r.height)
end)
```

A second group checks **invariants** on varied trees: nothing leaves its block's padding box, and every text gets
the height it needs. Add a case there when you find a layout that breaks.

## Framework specs

`tests/OrdaenCore/ui_spec.lua` loads `UI.lua` and the whole `OrdaenCore_UI` module against fake frames. The fake
font strings measure like the layout spec's, and are a little wider at any effective scale other than 1, as WoW's
fonts are. That makes scale mistakes visible: the spec draws a tooltip at a UI scale of 0.64 and checks that every
line the player would see fits the room the layout gave it.

What it covers: loading on first use only, one chat line when loading fails, theme fonts and colours, shrink to fit,
wrapping at `maxWidth`, refresh with `hidden` lines, owner checks on hide, placement sides including `"default"`,
measuring once.
