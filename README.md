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

![Example](https://private-user-images.githubusercontent.com/30277794/293306161-dc892ccb-a303-4232-abf4-1e56f9b4dc76.gif?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTEiLCJleHAiOjE3MDM4MjE2MzgsIm5iZiI6MTcwMzgyMTMzOCwicGF0aCI6Ii8zMDI3Nzc5NC8yOTMzMDYxNjEtZGM4OTJjY2ItYTMwMy00MjMyLWFiZjQtMWU1NmY5YjRkYzc2LmdpZj9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyMzEyMjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjMxMjI5VDAzNDIxOFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTljZTM2YzM2ZmU3NzI2ZTlkNTE4NjFhYTk1Y2MyZGVlNzAyMjhlYjU4Yzc0ZWNkMWZlMWJlOGU4MzZjNmM5ZWImWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JmFjdG9yX2lkPTAma2V5X2lkPTAmcmVwb19pZD0wIn0.wZ60-wv8rqTv1vHvatPARiMj_6gH3kKZ70PuE1Cy9us)

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
