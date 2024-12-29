return {
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local harpoon = require("harpoon")

            -- REQUIRED
            harpoon:setup()
            -- REQUIRED

            vim.keymap.set("n", "<space>a", function() harpoon:list():add() end)
            vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)

            vim.keymap.set("n", "<space>b", function() harpoon:list():select(1) end)
            vim.keymap.set("n", "<space>t", function() harpoon:list():select(2) end)
            vim.keymap.set("n", "<space>n", function() harpoon:list():select(3) end)
            vim.keymap.set("n", "<space>s", function() harpoon:list():select(4) end)
            vim.keymap.set("n", "<space>g", function() harpoon:list():select(5) end)
            vim.keymap.set("n", "<space>c", function() harpoon:list():select(6) end)
            vim.keymap.set("n", "<space>r", function() harpoon:list():select(7) end)
            vim.keymap.set("n", "<space>l", function() harpoon:list():select(8) end)
            vim.keymap.set("n", "<space>d", function() harpoon:list():select(9) end)

            -- Toggle previous & next buffers stored within Harpoon list
            vim.keymap.set("n", "<space>pp", function() harpoon:list():prev() end)
            vim.keymap.set("n", "<space>nn", function() harpoon:list():next() end)
        end
    }
}
