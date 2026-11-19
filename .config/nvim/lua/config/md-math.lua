-- Per-buffer LaTeX math highlighting in markdown, off by default.
-- markdown_inline parses any `$...$` pair as latex_block, so prices like
-- `$80k-$100k` get colored as math. queries/markdown_inline/injections.scm
-- uses the directive below, which only injects latex when the buffer opts in.
local M = {}

vim.treesitter.query.add_directive("set-md-math-lang!", function(_, _, source, _, metadata)
	if type(source) == "number" and vim.b[source].md_math then
		metadata["injection.language"] = "latex"
	end
end, { force = true })

function M.enabled(bufnr)
	return vim.b[bufnr or 0].md_math == true
end

function M.toggle()
	local bufnr = vim.api.nvim_get_current_buf()
	if vim.bo[bufnr].filetype ~= "markdown" then
		vim.notify("Markdown math: only for markdown buffers", vim.log.levels.WARN)
		return
	end
	vim.b[bufnr].md_math = not M.enabled(bufnr)
	-- Injections are cached per parse, so rebuild the parser to apply the change.
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	if ok and parser then
		parser:invalidate(true)
		vim.treesitter.stop(bufnr)
		vim.treesitter.start(bufnr)
	end
	pcall(function()
		require("lualine").refresh()
	end)
	vim.notify("Markdown math: " .. (M.enabled(bufnr) and "ON" or "OFF") .. " for this buffer")
end

return M
