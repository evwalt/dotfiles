-- Change this to switch themes; open nvim instances pick it up on restart.
-- Options: tokyonight-{storm,night,moon,day}
local colorscheme = "tokyonight-night"

return {
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,

		config = function()
			require("tokyonight").setup({
				-- Harbor Night: Tokyonight's structure with the palette of the Claude Code theme
				-- (~/.claude/themes/harbor-night.json) and the Alacritty background.
				-- on_colors runs after Tokyonight derives its secondary colors, so those are set here too.
				on_colors = function(c)
					c.bg = "#0c0c16"
					c.bg_dark = "#09090f"
					c.bg_dark1 = "#07070c"
					c.bg_highlight = "#151626"
					c.fg = "#c0c6d6"
					c.fg_dark = "#a8aec4"
					c.fg_gutter = "#2c2d45"
					c.dark3 = "#4a4c70"
					c.dark5 = "#6b7091"
					-- Brighter than Harbor's #6b7091 "inactive" so comments stay readable on the darker bg
					c.comment = "#757a9e"
					c.terminal_black = "#33344f"

					-- Periwinkle is Claude Code's accent (inline code, links); used as the main accent here
					c.blue = "#b1b9f9"
					c.blue0 = "#34406a"
					c.blue1 = "#7fa9d1"
					c.blue2 = "#6aaa9e"
					c.blue5 = "#a9c6e3"
					c.blue6 = "#c6dcef"
					c.blue7 = "#2a3352"
					c.cyan = "#93c4ba"
					c.green = "#8fbf98"
					c.green1 = "#6aaa9e"
					c.green2 = "#4f8f84"
					c.teal = "#6aaa9e"
					c.magenta = "#b9aef0"
					c.magenta2 = "#c98aa6"
					c.purple = "#a59fe6"
					c.orange = "#d9a184"
					c.yellow = "#dbbd84"
					c.red = "#e08592"
					c.red1 = "#c96a78"
					c.git = { add = "#5f9e86", change = "#6a8cbf", delete = "#b56473", ignore = c.dark3 }

					-- Derived colors
					c.diff = { add = "#16261f", delete = "#2a1720", change = "#151a2e", text = "#24304f" }
					c.black = "#07070c"
					c.border = "#33344f"
					c.border_highlight = "#4a4c70"
					c.bg_popup = c.bg_dark
					c.bg_statusline = c.bg_dark
					c.bg_sidebar = c.bg_dark
					c.bg_float = c.bg_dark
					c.bg_visual = "#252a48"
					c.bg_search = c.blue0
					c.fg_sidebar = c.fg_dark
					c.fg_float = c.fg
					c.error = c.red
					c.todo = "#7fa9d1"
					c.warning = c.yellow
					c.info = "#7fa9d1"
					c.hint = c.teal
					c.rainbow = { c.blue, c.yellow, c.green, c.teal, c.magenta, c.purple, c.orange, c.red }
					-- :terminal palette, same as alacritty.toml
					c.terminal = {
						black = "#2c2d45",
						black_bright = "#6b7091",
						red = "#e08592",
						red_bright = "#ebaab4",
						green = "#8fbf98",
						green_bright = "#b0d4b6",
						yellow = "#dbbd84",
						yellow_bright = "#ead5ad",
						blue = "#7fa9d1",
						blue_bright = "#a9c6e3",
						magenta = "#b996c4",
						magenta_bright = "#d4bddc",
						cyan = "#6aaa9e",
						cyan_bright = "#93c4ba",
						white = "#c0c6d6",
						white_bright = "#dce1ec",
					}
				end,
				on_highlights = function(hl, c)
					-- Set the groups directly: c.fg_gutter is also used for backgrounds (folds, popup selection)
					for _, group in ipairs({ "LineNr", "LineNrAbove", "LineNrBelow" }) do
						hl[group] = { fg = "#5f6485" }
					end
					hl.CursorLineNr = { fg = c.blue, bold = true }

					-- Markdown: neutral heading bars, one color per level; favorite colors on the most-used levels (H2/H3)
					local heading_fg = { "#dce1ec", c.blue, c.cyan, c.blue1, c.green, c.yellow }
					for i = 1, 6 do
						local fg = heading_fg[i]
						hl["@markup.heading." .. i .. ".markdown"] = { fg = fg, bg = "#151626", bold = true }
						hl["RenderMarkdownH" .. i .. "Bg"] = { bg = "#151626" }
					end
					hl["@markup.raw.markdown_inline"] = { fg = c.blue, bg = "#191b30" }
					hl["@markup.link.label.markdown_inline"] = { fg = c.blue }
					hl["@markup.link.url.markdown_inline"] = { fg = c.dark5, underline = true }
					hl.RenderMarkdownDash = { fg = "#3d3f5e" }
				end,
			})
			-- Apply the chosen theme here, since this plugin loads first.
			-- pcall: fall back to tokyonight-night if the name above is mistyped
			if not pcall(vim.cmd.colorscheme, colorscheme) then
				vim.cmd.colorscheme("tokyonight-night")
			end
		end,
	},
}
