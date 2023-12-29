---@class TreemonkeyOpts
---@field action? TreemonkeyAction?
---@field filter? fun(nodes: TSNode[]): TSNode[] A function to fileter candidate nodes
---@field highlight TreemonkeyOpts.highlight
---@field ignore_injections? boolean Whether or not (default) to ignore injected language
---@field include_root? boolean Whether or not (default) to include the root node in a choice
---@field labels string[] A list of labels for selecting nodes. Defaults to a-z
---@field steps? 1 | 2 Number of steps to choose a node. `nil` (default) for automatic decision
---@field experimental { treesitter_context: boolean } Options for experimental features

---@class TreemonkeyOpts.highlight Highlight groups
---@field first_node string A highlight group for the node of the first selection
---@field label string A highlight group for the labels

---@class TreemonkeyItem
---@field row integer
---@field col integer
---@field label string
---@field node TSNode

---@alias TreemonkeyAction fun(item: TreemonkeyItem): any
