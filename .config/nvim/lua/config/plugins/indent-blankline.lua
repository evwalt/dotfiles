return {
	"lukas-reineke/indent-blankline.nvim",
	main = "ibl",
	---@module "ibl"
	---@type ibl.config
	opts = {},
	config = function()
		-- Initialize ibl
		require("ibl").setup()

		-- Define highlight groups in order; these names are used to assign the colors.
		local highlight = {
			"RainbowRed",
			"RainbowYellow",
			"RainbowBlue",
			"RainbowOrange",
			"RainbowGreen",
			"RainbowViolet",
			"RainbowCyan",
		}
		local hooks = require("ibl.hooks")

		-- Create the highlight groups on colorscheme change
		hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
			-- Original colors:
			-- vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
			-- vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
			-- vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
			-- vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
			-- vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
			-- vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
			-- vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })

			-- TokyoNight colors:
			-- vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#f7768e" })
			-- vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#e0af68" })
			-- vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#7aa2f7" })
			-- vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#ff9e64" })
			-- vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#9ece6a" })
			-- vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#bb9af7" })
			-- vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#7dcfff" })

			-- Alternative palette: distinct from TokyoNight yet harmonizing with its dark background
			vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#ff8c8c" }) -- Soft Red
			vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#ffd47e" }) -- Warm, muted Yellow
			vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#91a7ff" }) -- Light, pastel Blue
			vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#ffb86c" }) -- Muted Orange
			vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#a3be8c" }) -- Subdued Green
			vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#cfa9e0" }) -- Soft Violet
			vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#88ffff" }) -- Light Cyan
		end)

		vim.g.rainbow_delimiters = { highlight = highlight }
		require("ibl").setup({ scope = { highlight = highlight } })

		hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
	end,
}
