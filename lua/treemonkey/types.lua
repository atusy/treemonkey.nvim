---@class TreemonkeyOpts
---@field action? TreemonkeyAction?
---@field filter? TreemonkeyFilter? A function to fileter candidate nodes
---@field highlight TreemonkeyOpts.highlight
---@field ignore_injections? boolean Whether or not (default) to ignore injected language
---@field include_root? boolean Whether or not (default) to include the root node in a choice
---@field labels string[] A list of labels for selecting nodes. Defaults to a-z
---@field steps? 1 | 2 Number of steps to choose a node. `nil` (default) for automatic decision
---@field experimental { treesitter_context: boolean } Options for experimental features

---@class TreemonkeyOpts.highlight Highlight groups
---@field backdrop? string On the node with the largest range among the choice
---@field first_node? string DEPRECATED. Use first_selected_node instead.
---@field first_selected_label? string On the first selected label
---@field first_selected_node? string On the first selected node
---@field label? string On labels

---@class TreemonkeyItem
---@field row integer
---@field col integer
---@field label string
---@field node TSNode

---@alias TreemonkeyAction fun(item: TreemonkeyItem): any
---@alias TreemonkeyFilter fun(nodes: TSNode[]): TSNode[]
