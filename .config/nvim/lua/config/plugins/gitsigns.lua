return {
	"lewis6991/gitsigns.nvim",
	-- enabled = false,
	config = function()
		require("gitsigns").setup({ current_line_blame = true })
	end,
}
