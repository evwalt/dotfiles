local set = vim.opt_local

set.expandtab = true

-- Automatically add a newline at the end of the file on save
-- vim.api.nvim_create_autocmd("BufWritePre", {
--     pattern = "*.lua",
--     callback = function()
--         local last_line = vim.api.nvim_buf_get_lines(0, -2, -1, false)[1]
--         if last_line ~= "" then
--             vim.api.nvim_buf_set_lines(0, -1, -1, false, { "" })
--         end
--     end,
--     desc = "Ensure newline at end of .lua files",
-- })

