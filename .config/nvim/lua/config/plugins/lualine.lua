return {
	"nvim-lualine/lualine.nvim",
	-- enabled = false,
	event = "VeryLazy",
	dependencies = { "nvim-tree/nvim-web-devicons" },

	config = function()
		-- Left padding only, so neighbors are one space apart
		local pad = { left = 1, right = 0 }

		-- Text colors only: take the colorscheme's lualine theme, drop every section
		-- background, and show the mode color (section a, mirrored in y/z) as text.
		local function fg_only_theme()
			package.loaded["lualine.themes.auto"] = nil
			local theme = vim.deepcopy(require("lualine.themes.auto"))
			local bg = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false }).bg
			bg = bg and string.format("#%06x", bg) or "NONE"
			for _, mode in pairs(theme) do
				for name, hl in pairs(mode) do
					if name == "a" or name == "z" then
						hl.fg = hl.bg
					end
					hl.bg = bg
				end
			end
			return theme
		end

		local opts = {
			options = {
				icons_enabled = true,
				theme = fg_only_theme(),
				-- No separator glyphs; components are split by one space (see `pad`)
				component_separators = "",
				section_separators = "",
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
				lualine_a = { { "mode", padding = 0 } },
				lualine_b = {
					{ "branch", padding = pad },
					{ "diff", padding = pad },
					{ "diagnostics", padding = pad },
				},
				-- lualine_c = { "filename" },
				lualine_c = {
					{ "filename", path = 3, padding = pad },
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
						-- Harbor Night warning; other themes use their own warning color.
						color = function()
							if (vim.g.colors_name or ""):find("^tokyonight") then
								return { fg = "#dbbd84" }
							end
							local fg = vim.api.nvim_get_hl(0, { name = "DiagnosticWarn", link = false }).fg
							return fg and { fg = string.format("#%06x", fg) } or nil
						end,
						padding = pad,
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
						padding = pad,
					},
					{
						-- Two independent toggles: ltex spelling mode (<space><space>ts) where
						-- ltex is attached, and Tree-sitter math highlighting (<space><space>tm)
						-- in markdown buffers, e.g. "ltex:loose md:nomath"
						function()
							local parts = {}
							if #vim.lsp.get_clients({ bufnr = 0, name = "ltex_plus" }) > 0 then
								table.insert(parts, "ltex:" .. (require("config.ltex-filter").mode()))
							end
							if vim.bo.filetype == "markdown" then
								table.insert(parts, "md:" .. (require("config.md-math").enabled() and "math" or "nomath"))
							end
							return table.concat(parts, " ")
						end,
						padding = pad,
					},
					{ "encoding", padding = pad },
					-- Narrow windows show just the filetype icon, wide ones icon + name
					{
						"filetype",
						icon_only = true,
						cond = function()
							return vim.fn.winwidth(0) < 80
						end,
						padding = pad,
					},
					{
						"filetype",
						cond = function()
							return vim.fn.winwidth(0) >= 80
						end,
						padding = pad,
					},
				},
				-- lualine_x = {
				-- 	{
				-- 		require("noice").api.statusline.mode.get,
				-- 		cond = require("noice").api.statusline.mode.has,
				-- 		color = { fg = "#ff9e64" },
				-- 	},
				-- },
				lualine_y = { { "progress", padding = pad } },
				lualine_z = {
					{
						-- line:column with the line padded to the file's longest line number,
						-- so the right edge stays put without trailing spaces
						function()
							local width = #tostring(vim.fn.line("$"))
							return string.format("%" .. width .. "d:%d", vim.fn.line("."), vim.fn.virtcol("."))
						end,
						padding = pad,
					},
				},
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
		}
		require("lualine").setup(opts)
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("lualine_fg_only", { clear = true }),
			callback = function()
				opts.options.theme = fg_only_theme()
				require("lualine").setup(opts)
			end,
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
