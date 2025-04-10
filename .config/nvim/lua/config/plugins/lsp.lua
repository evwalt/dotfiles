-- Tip: run `:h ins-completion` (Insert mode completion)

return {
	"neovim/nvim-lspconfig",
	-- enabled = false,
	dependencies = {
		"saghen/blink.cmp",
		{
			"folke/lazydev.nvim",
			ft = "lua", -- only load on lua files
			opts = {
				library = {
					-- See the configuration section for more details
					-- Load luvit types when the `vim.uv` word is found
					{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
				},
			},
		},
	},

	config = function()
		local lspconfig = require("lspconfig")
		local capabilities = require("blink.cmp").get_lsp_capabilities()

		lspconfig.emmet_ls.setup({
			-- on_attach = on_attach,
			capabilities = capabilities,
			filetypes = {
				"css",
				"eruby",
				"html",
				"javascript",
				"javascriptreact",
				"json",
				"less",
				"sass",
				"scss",
				"svelte",
				"pug",
				"typescriptreact",
				"vue",
			},
			init_options = {
				html = {
					options = {
						-- For possible options, see: https://github.com/emmetio/emmet/blob/master/src/config.ts#L79-L267
						["bem.enabled"] = true,
					},
				},
			},
		})

		lspconfig.cssls.setup({ capabilities = capabilities })

		lspconfig.eslint.setup({ capabilities = capabilities })

		lspconfig.html.setup({ capabilities = capabilities })

		lspconfig.jdtls.setup({ capabilities = capabilities })

		lspconfig.json.setup({ capabilities = capabilities })

		lspconfig.ltex.setup({
			settings = {
				ltex = {
					language = "en-US",
					disabledRules = {
						-- For options, see the following:
						-- <https://community.languagetool.org/rule/list>
						-- <https://www.reddit.com/r/neovim/comments/1hsmyod/disable_some_diagnostics_within_ltexls/?utm_source=chatgpt.com>
						-- <https://www.reddit.com/r/neovim/comments/1hsmyod/comment/m5z2i66/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button>
						["en-US"] = { "EN_SPECIFIC_CASE", "I_LOWERCASE", "UPPERCASE_SENTENCE_START" },
					},
					completionEnabled = true,
					dictionary = {
						["en-US"] = { "hw", "js", "TODO" },
					},
					checkFrequency = "save",
				},
			},
		})

		lspconfig.lua_ls.setup({ capabilities = capabilities })

		lspconfig.pyright.setup({ capabilities = capabilities })

		lspconfig.tailwindcss.setup({
			capabilities = capabilities,
			filetypes = {
				"css",
				"html",
				"javascript",
				"javascriptreact",
				"less",
				"sass",
				"scss",
				"svelte",
				"typescriptreact",
				"vue",
			},
		})

		lspconfig.ts_ls.setup({ capabilities = capabilities })

		-- LSP Default Keymaps in Neovim Nightly Build
		--
		-- vim.keymap.set('n', 'grn', vim.lsp.buf.rename)
		-- vim.keymap.set('n', 'gra', vim.lsp.buf.code_action)
		-- vim.keymap.set('n', 'grr', vim.lsp.buf.references)
		-- vim.keymap.set('n', 'gri', vim.lsp.buf.implementation)
		-- vim.keymap.set('n', 'gO', vim.lsp.buf.document_symbol)
		-- vim.keymap.set('n', '<C-s>', vim.lsp.buf.signature_help)
		--
	end,
}
