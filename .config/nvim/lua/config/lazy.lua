-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
-- vim.g.mapleader = " "
-- vim.g.maplocalleader = " "

-- Headless runs (`nvim --headless "+Lazy! sync"`) print plugin names in ANSI magenta
-- and task names in ANSI cyan. Recolor to Harbor Night: plugin names periwinkle
-- (Alacritty bright blue), task names champagne #cdbda2 (truecolor; not in the ANSI palette).
-- Guarded: lazy.terminal is internal, so a lazy update that renames it just skips this.
local ok, term = pcall(require, "lazy.terminal")
if ok and type(term) == "table" and type(term.colors) == "table" and term.bright_blue and term.color then
	term.colors.champagne = "\27[38;2;205;189;162m"
	term.magenta = term.bright_blue
	term.cyan = function(text)
		return term.color(text, "champagne")
	end
end

-- Setup lazy.nvim
require("lazy").setup({
	spec = {
		-- { 'folke/tokyonight.nvim', config = function() vim.cmd.colorscheme 'tokyonight' end },
		-- import your plugins
		{ import = "config.plugins" },
	},
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	-- install = { colorscheme = { "habamax" } },
	-- automatically check for plugin updates
	checker = { enabled = true },
})
