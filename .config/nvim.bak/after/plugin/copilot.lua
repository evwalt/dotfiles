vim.cmd([[imap <silent><script><expr> <C-a> copilot#Accept("\<CR>")]])
vim.g.copilot_no_tab_map = true

local function disable_copilot()
	vim.cmd("Copilot disable")
end

-- disable_copilot()
