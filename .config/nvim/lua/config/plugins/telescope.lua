return {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    -- or '...' , branch = '0.1.x',
    dependencies = { 'nvim-lua/plenary.nvim',
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }
    },
    config = function()
        require('telescope').setup {
            extensions = {
                fzf = {}
            },

            defaults = require('telescope.themes').get_ivy {},
        }

        require('telescope').load_extension('fzf')

        vim.keymap.set('n', '<space><space>', require('telescope.builtin').find_files)
        -- vim.keymap.set('n', '<space>fd', require('telescope.builtin').find_files {
        --     cwd = require('telescope.utils').buffer_dir(),
        -- })
        vim.keymap.set('n', '<space>fh', require('telescope.builtin').help_tags)

        require 'config.telescope.multigrep'.setup()
    end,
}
