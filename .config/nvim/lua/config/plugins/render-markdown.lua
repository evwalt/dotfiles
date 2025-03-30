return {
	"MeanderingProgrammer/render-markdown.nvim",
	-- enabled = false,
	dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.nvim" }, -- if you use the mini.nvim suite
	-- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
	-- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
	---@module 'render-markdown'
	---@type render.md.UserConfig
	opts = {
		strikethrough = true,
	},

	config = function()
		vim.api.nvim_set_hl(0, "@markup.strikethrough", { strikethrough = true })
		vim.api.nvim_set_hl(0, "markdown_inline.Strikethrough", { strikethrough = true })
		vim.api.nvim_set_hl(0, "markdownStrike", { strikethrough = true })
		vim.api.nvim_set_hl(0, "markdownStrikeDelimiter", { strikethrough = true })
	end,
}
