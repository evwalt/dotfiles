-- JSON
--

-- Automatically add a newline at the end of the file on save
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = { 'package.json' },
    callback = function()
        vim.bo.tabstop = 2
        vim.bo.shiftwidth = 2
        vim.bo.expandtab = true
        print("Custom settings applied for " .. vim.fn.expand("%:t")) -- Debugging message
    end,
    desc = "Set tab width to 2 and use spaces for certain JSON files like package.json",
})

