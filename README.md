# treemonkey.nvim

Yet another label-based node selection plugin.

There are some cases that start or end of the node position overlaps with the other nodes.
If labels are overlayed, there is a difficulty on selecting the intended one (e.g., [nvim-treehopper](https://github.com/mfussenegger/nvim-treehopper) or [leap-ast.nvim](https://github.com/ggandor/leap-ast.nvim)).
If labels are inserted inline, your eyes may fail to track the node(e.g., [flash.nvim](https://github.com/folke/flash.nvim)).

Instead, this plugin does...

1. Label start of nodes with lower case letters and end of nodes with the corresponding upper case letters.
2. Ask user to input a label.
3. If there are any labels hidden by the chosen label, then ask again to choose the label from the subset of choises.
4. Select the node of the choice.

It's like monkey hanging around the Abstract Syntax Tree. Isn't it?

![Example](https://github.com/atusy/treemonkey.nvim/assets/30277794/42aceb5e-0efc-40a3-8d3c-0ab5e56e43ac)

## Requirements

- [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)

## Example

```lua
vim.keymap.set({"x", "o"}, "m", function()
    require("treemonkey").select({ ignore_injections = false })
end)
```
