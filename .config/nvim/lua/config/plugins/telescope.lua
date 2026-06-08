return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.8",
	-- or '...' , branch = '0.1.x',
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
	},

	config = function()
		local telescope = require("telescope")

		telescope.setup({
			extensions = {
				fzf = {},
			},

			-- defaults = require("telescope.themes").get_ivy({}),
			defaults = {
				file_ignore_patterns = { "^.git/", "%.DS_Store$" },
				layout_strategy = "vertical",
				layout_config = {
					vertical = {
						prompt_position = "top",
						mirror = "false",
					},
				},
				sorting_strategy = "ascending",
			},
			pickers = {
				find_files = {
					hidden = true,
					no_ignore = false,
					follow = true,
				},
			},
		})

		telescope.load_extension("fzf")

		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")
		local builtin = require("telescope.builtin")

		local find_dirs = function()
			builtin.find_files({
				prompt_title = "Find Directories",
				-- use the following to show ignored directories in search
				-- find_command = { "fd", "--type", "directory", "--hidden", "--no-ignore", "--exclude", ".git" },
				find_command = { "fd", "--type", "directory", "--hidden", "--exclude", ".git" },
				attach_mappings = function(_, map)
					local open_in_oil = function(prompt_bufnr)
						local entry = action_state.get_selected_entry()
						local path = entry.path or entry[1] or entry.value
						actions.close(prompt_bufnr)
						require("oil").open(path)
					end

					map("i", "<CR>", open_in_oil)
					map("n", "<CR>", open_in_oil)
					return true
				end,
			})
		end

		-- local find_files = function()
		-- 	builtin.find_files({ search_dirs = { vim.fn.fnamemodify(vim.fn.getcwd(), ":h") } })
		-- end
		local find_files = builtin.find_files
		local help_tags = builtin.help_tags

		vim.keymap.set("n", "<space><space>", find_files)
		vim.keymap.set("n", "<space><space><space>", find_files)
		vim.keymap.set("n", "<space>fh", help_tags)
		vim.keymap.set("n", "<space>fb", ":Telescope buffers<CR>")
		vim.keymap.set("n", "<space>fd", find_dirs)

		require("config.telescope.multigrep").setup()
	end,
}
