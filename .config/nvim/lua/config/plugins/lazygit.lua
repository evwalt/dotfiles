return {
	"kdheepak/lazygit.nvim",
	-- enabled = false,
	dependencies = { "nvim-lua/plenary.nvim" },
	cmd = { "LazyGit", "LazyGitCurrentFile", "LazyGitLog", "LazyGitFilter", "LazyGitFilterCurrentFile" },
	keys = {
		{ "<space><space>g", "<cmd>LazyGit<cr>", desc = "LazyGit" },
	},
}
