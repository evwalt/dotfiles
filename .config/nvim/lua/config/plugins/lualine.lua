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

		-- Narrow windows drop pieces in this order until the line fits: encoding,
		-- filetype name (icon stays), directory path (shortened, then gone),
		-- md:math, ltex:mode. Sections a and b are measured as they render (they
		-- draw before c), and the filename component in c decides for x.
		local left_w = 0
		local show = { enc = true, ftname = true, path = 0, md = true, ltex = true }

		local function vis(s)
			return vim.fn.strdisplaywidth((s:gsub("%%#[^#]*#", ""):gsub("%%%*", "")))
		end
		-- fmt hook that adds a section a/b component's rendered width to left_w
		local function measure(extra, reset)
			return function(s)
				if reset then
					left_w = 0
				end
				if s ~= "" then
					left_w = left_w + vis(s) + extra
				end
				return s
			end
		end

		local function recording()
			local reg = vim.fn.reg_recording()
			return reg ~= "" and ("Recording @" .. reg) or ""
		end
		local function bufpos()
			-- position in the bufferline (what the <space>'' style jump keys use), not the nvim buffer number
			local cur = vim.api.nvim_get_current_buf()
			_G.nvim_bufferline() -- bufferline only fills its list when drawn, so refresh it while hidden
			for i, el in ipairs(require("bufferline").get_elements().elements) do
				if el.id == cur then
					return tostring(i)
				end
			end
			return ""
		end
		-- ltex spelling mode (<space><space>ts) where ltex is attached
		local function ltex()
			if #vim.lsp.get_clients({ bufnr = 0, name = "ltex_plus" }) > 0 then
				return "ltex:" .. require("config.ltex-filter").mode()
			end
			return ""
		end
		-- Tree-sitter math highlighting (<space><space>tm) in markdown buffers
		local function md()
			if vim.bo.filetype == "markdown" then
				return "md:" .. (require("config.md-math").enabled() and "math" or "nomath")
			end
			return ""
		end
		-- line:column with the line padded to the file's longest line number,
		-- so the right edge stays put without trailing spaces
		local function location()
			local width = #tostring(vim.fn.line("$"))
			return string.format("%" .. width .. "d:%d", vim.fn.line("."), vim.fn.virtcol("."))
		end
		-- 0 = full path, 1 = shortened dirs, 2 = name only
		local function filename(level)
			local name = vim.fn.expand("%:p:~")
			if name == "" then
				name = "[No Name]"
			elseif level == 1 then
				name = vim.fn.pathshorten(name)
			elseif level == 2 then
				name = vim.fn.expand("%:t")
			end
			if vim.bo.modified then
				name = name .. " [+]"
			end
			if not vim.bo.modifiable or vim.bo.readonly then
				name = name .. " [-]"
			end
			return name
		end

		local function layout()
			-- width of a padded component, 0 when it renders nothing
			local function w(s)
				return s == "" and 0 or 1 + vim.fn.strdisplaywidth(s)
			end
			local ft = vim.bo.filetype
			local enc = vim.bo.fileencoding
			local ftname = ft ~= "" and 1 + vim.fn.strdisplaywidth(ft) or 0
			local fixed = left_w + w(recording()) + w(bufpos()) + w("Top") + w(location()) + (ft ~= "" and 2 or 0)
			local opt = { ltex = w(ltex()), md = w(md()), enc = w(enc) }
			local s = { enc = true, ftname = true, path = 0, md = true, ltex = true }
			local function total()
				return fixed
					+ w(filename(s.path))
					+ (s.enc and opt.enc or 0)
					+ (s.ftname and ftname or 0)
					+ (s.md and opt.md or 0)
					+ (s.ltex and opt.ltex or 0)
			end
			local drops = {
				function() s.enc = false end,
				function() s.ftname = false end,
				function() s.path = 1 end,
				function() s.path = 2 end,
				function() s.md = false end,
				function() s.ltex = false end,
			}
			local avail = vim.fn.winwidth(0)
			for _, drop in ipairs(drops) do
				if total() <= avail then
					break
				end
				drop()
			end
			show = s
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
				lualine_a = { { "mode", padding = 0, fmt = measure(0, true) } },
				lualine_b = {
					{ "branch", padding = pad, fmt = measure(3) }, -- 3 = padding + icon and its space
					{ "diff", padding = pad, fmt = measure(1) },
					{ "diagnostics", padding = pad, fmt = measure(1) },
				},
				lualine_c = {
					{
						function()
							layout()
							return (filename(show.path):gsub("%%", "%%%%"))
						end,
						padding = pad,
					},
				},
				lualine_x = {
					{
						recording,
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
					{ bufpos, padding = pad },
					{
						ltex,
						cond = function()
							return show.ltex
						end,
						padding = pad,
					},
					{
						md,
						cond = function()
							return show.md
						end,
						padding = pad,
					},
					{
						"encoding",
						cond = function()
							return show.enc
						end,
						padding = pad,
					},
					{
						"filetype",
						icon_only = true,
						cond = function()
							return not show.ftname
						end,
						padding = pad,
					},
					{
						"filetype",
						cond = function()
							return show.ftname
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
				lualine_z = { { location, padding = pad } },
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
