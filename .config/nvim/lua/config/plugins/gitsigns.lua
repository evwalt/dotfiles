return {
	"lewis6991/gitsigns.nvim",
	-- enabled = false,
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("gitsigns").setup({ current_line_blame = true })
	end,
}
