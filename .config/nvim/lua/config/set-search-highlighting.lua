--- Search Highlighting ---

local group = vim.api.nvim_create_augroup("vimrc_incsearch_highlight", { clear = true })

vim.api.nvim_create_autocmd("CmdlineEnter", {
	pattern = { "/", "?" },
	command = "set hlsearch",
	group = group,
	desc = "Enable search highlighting on entering search mode",
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
	pattern = { "/", "?" },
	command = "set nohlsearch",
	group = group,
	desc = "Disable search highlighting on leaving search mode",
})

local function temporary_hlsearch()
	vim.opt.hlsearch = true
	vim.defer_fn(function()
		vim.opt.hlsearch = false
	end, 3000)
end

vim.on_key(function(key)
	local mode = vim.api.nvim_get_mode().mode
	if mode == "n" and (key == "*" or key == "#" or key == "n" or key == "N") then
		vim.schedule(temporary_hlsearch)
	end
end)
