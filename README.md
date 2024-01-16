# treemonkey.nvim

Yet another label-based node selection plugin.

There are some cases that start or end of the node position overlaps with the other nodes.
If labels are overlayed, there is a difficulty on selecting the intended one (e.g., [nvim-treehopper](https://github.com/mfussenegger/nvim-treehopper) or [leap-ast.nvim](https://github.com/ggandor/leap-ast.nvim)).
If labels are inserted inline, your eyes may fail to track the node (e.g., [flash.nvim](https://github.com/folke/flash.nvim)).

Instead, this plugin does...

1. Label start of nodes with lower case letters and end of nodes with the corresponding upper case letters.
2. Ask user to input a label.
3. If there are any labels hidden by the chosen label, then ask again to choose the label from the subset of choises.
4. Select the node of the choice.

It's like monkey hanging around the Abstract Syntax Tree. Isn't it?

![2023-12-29 12-39-32 mkv](https://github.com/atusy/treemonkey.nvim/assets/30277794/dc892ccb-a303-4232-abf4-1e56f9b4dc76)

## Example

```lua
vim.keymap.set({"x", "o"}, "m", function()
  require("treemonkey").select({
    ignore_injections = false,
    highlight = { backdrop = "Comment" }
  })
end)
```

With [lazy.nvim](https://github.com/folke/lazy.nvim/), ...

```lua
{
  "https://github.com/atusy/treemonkey.nvim",
  init = function()
    vim.keymap.set({"x", "o"}, "m", function()
      require("treemonkey").select({ ignore_injections = false })
    end)
  end
}
```
