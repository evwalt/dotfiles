--- Top-level Configuration ---
-- Note: many settings come from [Advent of Neovim](https://www.youtube.com/playlist?list=PLep05UYkc6wTyBe7kPjQFWVXTlhKeQejM). Some settings were created as I was going through it.

--- Temporary Workaround for the Command `:Inspect` ---
-- See <https://github.com/neovim/neovim/issues/31675#issuecomment-2558405042>)
vim.hl = vim.highlight

--- Settings ---
require("config.set")
-- Registers the query directive markdown_inline injections need (before any parse)
require("config.md-math")

--- Keymaps ---
require("config.keymaps")
require("config.keyhelp")

--- Plugin Management ---
require("config.lazy")
