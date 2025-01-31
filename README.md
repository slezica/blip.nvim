# Blip

My very own NeoVim jumping plugin, used all around the world by a single user.

### Why?

Because I can't stop myself from customizing everything I use, but also:

- Case-insensitive targeting, upper-case labels
- Can type any amount of characters, won't accidentally jump if fingers overtype
- `Enter` will also jump to the closest label, which is colored differently
- That's pretty much it

### How?

Call the `blip.jump()` function to initiate a jump:

```lua
require('blip').jump()
```

Now enter any text you see on the window, of any length. Labels will appear with the 2nd character, and
disappear as further characters narrow the choices. The closest label has a different color, and can
also be jumped to by pressing `Enter`.

You (meaning I) can somewhat configure the call using:

```lua
require('blip').jump({
    labels = { 'A', 'B', 'C' }, -- defaults to blip.default_labels
    direction = 'both' -- defaults to 'both', can also be 'forward' or 'backward'
})
```

### Future Work

- Come up with ideas for improvement
