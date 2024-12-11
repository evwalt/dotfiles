-- Automatically install and set up packer.nvim on any machine this configuration is cloned to.
-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd([[packadd packer.nvim]])

return require("packer").startup(function(use)
	-- Packer can manage itself
	use("wbthomason/packer.nvim")

	use({
		"nvim-telescope/telescope.nvim",
		tag = "0.1.2",
		-- or                            , branch = '0.1.x',
		requires = { { "nvim-lua/plenary.nvim" } },
	})

	use({ "rose-pine/neovim", as = "rose-pine" })
	use("neovim/nvim-lspconfig")
	use("williamboman/mason.nvim")
	use("williamboman/mason-lspconfig.nvim")
	use("sbdchd/neoformat")
	use("nvim-treesitter/nvim-treesitter", { run = ":TSUpdate" })
	use("nvim-treesitter/playground")
	use("theprimeagen/harpoon")
	use("mbbill/undotree")
	-- use("tpope/vim-fugitive")
	use("github/copilot.vim")
	use("typescript-language-server/typescript-language-server")
	-- use("tailwindlabs/tailwindcss-intellisense")
	use("rust-lang/rust-analyzer")
	use("windwp/nvim-ts-autotag")
	use({
		"numToStr/comment.nvim",
		config = function()
			require("comment").setup()
		end,
	})

	use("lukas-reineke/indent-blankline.nvim")

	-- install without yarn or npm
	use({
		"iamcco/markdown-preview.nvim",
		run = function()
			vim.fn["mkdp#util#install"]()
		end,
	})

	use({
		"laytan/tailwind-sorter.nvim",
		requires = { "nvim-treesitter/nvim-treesitter", "nvim-lua/plenary.nvim" },
		config = function()
			require("tailwind-sorter").setup()
		end,
		run = "cd formatter && npm i && npm run build",
	})

	-- use("christoomey/vim-tmux-navigator")
end)
