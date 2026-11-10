return {
	"nvim-lualine/lualine.nvim",
	-- enabled = false,
	event = "VeryLazy",
	dependencies = { "nvim-tree/nvim-web-devicons" },

	config = function()
		require("lualine").setup({
			options = {
				icons_enabled = true,
				theme = "auto",
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
				disabled_filetypes = {
					statusline = {},
					winbar = {},
				},
				ignore_focus = {},
				always_divide_middle = true,
				always_show_tabline = true,
				globalstatus = false,
				refresh = {
					statusline = 1000,
					tabline = 1000,
					winbar = 1000,
					refresh_time = 16, -- ~60fps
					events = {
						"WinEnter",
						"BufEnter",
						"BufWritePost",
						"SessionLoadPost",
						"FileChangedShellPost",
						"VimResized",
						"Filetype",
						"CursorMoved",
						"CursorMovedI",
						"ModeChanged",
					},
				},
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "branch", "diff", "diagnostics" },
				-- lualine_c = { "filename" },
				lualine_c = {
					{ "filename", path = 3 },
				},
				-- lualine_x = { "encoding", "fileformat", "filetype" },
				lualine_x = {
					{
						function()
							local reg = vim.fn.reg_recording()
							-- If a macro is being recorded, show "Recording @<register>"
							if reg ~= "" then
								return "Recording @" .. reg
							else
								return ""
							end
						end,
						-- Tokyonight's orange; other themes use their own warning color.
						color = function()
							if (vim.g.colors_name or ""):find("^tokyonight") then
								return { fg = "#ff9e64" }
							end
							local fg = vim.api.nvim_get_hl(0, { name = "DiagnosticWarn", link = false }).fg
							return fg and { fg = string.format("#%06x", fg) } or nil
						end,
					},
					{
						function()
							-- position in the bufferline (what the <space>'' style jump keys use), not the nvim buffer number
							local cur = vim.api.nvim_get_current_buf()
							_G.nvim_bufferline() -- bufferline only fills its list when drawn, so refresh it while hidden
							for i, el in ipairs(require("bufferline").get_elements().elements) do
								if el.id == cur then
									return tostring(i)
								end
							end
							return ""
						end,
					},
					"encoding",
					"filetype",
				},
				-- lualine_x = {
				-- 	{
				-- 		require("noice").api.statusline.mode.get,
				-- 		cond = require("noice").api.statusline.mode.has,
				-- 		color = { fg = "#ff9e64" },
				-- 	},
				-- },
				lualine_y = { "progress" },
				lualine_z = { "location" },
			},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = { "filename" },
				lualine_x = { "location" },
				lualine_y = {},
				lualine_z = {},
			},
			tabline = {},
			winbar = {},
			inactive_winbar = {},
			extensions = {},
		})

		-- Statusline (mode, file, position, encoding...) is hidden by default; <space>ts toggles it.
		-- The all-caps global is saved in shada (already loaded by VeryLazy), so it survives restarts.
		vim.o.laststatus = vim.g.UI_LASTSTATUS or 0
		vim.keymap.set("n", "<space>ts", function()
			vim.o.laststatus = vim.o.laststatus == 0 and 2 or 0
			vim.g.UI_LASTSTATUS = vim.o.laststatus
		end, { desc = "Toggle statusline" })
	end,
}
