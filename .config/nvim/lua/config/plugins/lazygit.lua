-- Floating lazygit on a yadm repo (work tree is $HOME, so the plugin's repo detection can't find it)
local function yadm_lazygit(yadm_args)
	local buf = vim.api.nvim_create_buf(false, true)
	local width = math.floor(vim.o.columns * 0.9)
	local height = math.floor(vim.o.lines * 0.9)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		border = "rounded",
	})
	vim.fn.jobstart(vim.list_extend({ "yadm" }, vim.list_extend(yadm_args, { "enter", "lazygit" })), {
		term = true,
		on_exit = function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end,
	})
	vim.cmd.startinsert()
end

return {
	"kdheepak/lazygit.nvim",
	-- enabled = false,
	dependencies = { "nvim-lua/plenary.nvim" },
	cmd = { "LazyGit", "LazyGitCurrentFile", "LazyGitLog", "LazyGitFilter", "LazyGitFilterCurrentFile" },
	keys = {
		{ "<space><space>g", "<cmd>LazyGit<cr>", desc = "LazyGit" },
		{
			"<space><space>y",
			function()
				yadm_lazygit({})
			end,
			desc = "LazyGit (yadm public)",
		},
		{
			"<space><space>yr",
			function()
				yadm_lazygit({
					"--yadm-dir",
					vim.fn.expand("~/.config/yadm-private"),
					"--yadm-data",
					vim.fn.expand("~/.local/share/yadm-private"),
				})
			end,
			desc = "LazyGit (yadm private)",
		},
	},
}
