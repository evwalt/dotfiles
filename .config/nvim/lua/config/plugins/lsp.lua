-- Tip: run `:h ins-completion` (Insert mode completion)
local HOME = os.getenv("HOME")
local ltex_dictionary = dofile(HOME .. "/ltex-dictionary.lua")

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

		vim.lsp.config("codebook-lsp", {
			cmd = { "codebook-lsp", "serve" },
			filetypes = {
				"c",
				"css",
				-- "gitcommit",
				"go",
				"haskell",
				-- "html",
				"java",
				"javascript",
				"javascriptreact",
				"lua",
				-- "markdown",
				"php",
				"python",
				"ruby",
				"rust",
				"swift",
				"toml",
				-- "text",
				"typescript",
				"typescriptreact",
				"typst",
				"zig",
			},
			root_markers = { ".git", "codebook.toml", ".codebook.toml" },
		})
		vim.lsp.enable("codebook-lsp")

		vim.lsp.config("cssls", { capabilities = capabilities })
		vim.lsp.enable("cssls")

		vim.lsp.config("emmet_ls", {
			-- on_attach = on_attach,
			capabilities = capabilities,
			filetypes = {
				"css",
				"eruby",
				"html",
				"javascript",
				"javascriptreact",
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
		vim.lsp.enable("emmet_ls")

		vim.lsp.config("eslint", { capabilities = capabilities })
		vim.lsp.enable("eslint")

		vim.lsp.config("html", { capabilities = capabilities })
		vim.lsp.enable("html")

		vim.lsp.config("jdtls", { capabilities = capabilities })
		vim.lsp.enable("jdtls")

		vim.lsp.config("jsonls", { capabilities = capabilities })
		vim.lsp.enable("jsonls")

		vim.lsp.config("ltex_plus", {
			-- capabilities = capabilities,
			filetypes = {
				"bib",
				"context",
				"gitcommit",
				"html",
				"markdown",
				"org",
				"pandoc",
				"plaintex",
				"quarto",
				"mail",
				"mdx",
				"rmd",
				"rnoweb",
				"rst",
				"tex",
				"text",
				-- "typst",
				"xhtml",
			},
			settings = {
				ltex = {
					checkFrequency = "save",
					completionEnabled = true,
					dictionary = {
						["en-US"] = ltex_dictionary,
					},
					disabledRules = {
						-- For options, see the following:
						-- <https://community.languagetool.org/rule/list>
						-- <https://www.reddit.com/r/neovim/comments/1hsmyod/disable_some_diagnostics_within_ltexls/?utm_source=chatgpt.com>
						-- <https://www.reddit.com/r/neovim/comments/1hsmyod/comment/m5z2i66/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button>
						["en-US"] = { "EN_SPECIFIC_CASE", "I_LOWERCASE", "UPPERCASE_SENTENCE_START" },
					},
					enabled = {
						"bib",
						"context",
						"gitcommit",
						"html",
						"markdown",
						"org",
						"pandoc",
						"plaintex",
						"quarto",
						"mail",
						"mdx",
						"rmd",
						"rnoweb",
						"rst",
						"tex",
						"latex",
						"text",
						-- "typst",
						"xhtml",
					},
					language = "en-US",
				},
			},
		})
		vim.lsp.enable("ltex_plus")

		vim.lsp.config("lua_ls", { capabilities = capabilities })
		vim.lsp.enable("lua_ls")

		vim.lsp.config("prismals", { capabilities = capabilities })
		vim.lsp.enable("prismals")

		vim.lsp.config("pyright", { capabilities = capabilities })
		vim.lsp.enable("pyright")

		vim.lsp.config("tailwindcss", {
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
		vim.lsp.enable("tailwindcss")

		vim.lsp.config("ts_ls", { capabilities = capabilities })
		vim.lsp.enable("ts_ls")

		vim.lsp.config("tinymist", {
			capabilities = capabilities,
			settings = {
				formatterMode = "typstyle",
				exportPdf = "onType",
				semanticTokens = "disable",
			},
		})
		vim.lsp.enable("tinymist")

		-- vim.lsp.enable("typos_lsp")
		-- vim.lsp.config("typos_lsp", {
		-- 	-- capabilities = capabilities,
		-- 	-- typos-lsp must be on your PATH, or otherwise change this to an absolute path to typos-lsp
		-- 	-- defaults to typos-lsp if unspecified
		-- 	cmd = { "typos-lsp" },
		-- 	-- Logging level of the language server. Logs appear in :LspLog. Defaults to error.
		-- 	cmd_env = { RUST_LOG = "error" },
		-- 	init_options = {
		-- 		-- Custom config. Used together with a config file found in the workspace or its parents,
		-- 		-- taking precedence for settings declared in both.
		-- 		-- Equivalent to the typos `--config` cli argument.
		-- 		config = "~/code/typos-lsp/crates/typos-lsp/tests/typos.toml",
		-- 		-- How typos are rendered in the editor, can be one of an Error, Warning, Info or Hint.
		-- 		-- Defaults to Info.
		-- 		diagnosticSeverity = "Info",
		-- 	},
		-- })
		-- Enable debug logs for the LSP client. Recommended for debugging only.
		-- vim.lsp.set_log_level("debug")

		--- LSP Default Keymaps in Neovim Nightly Build ---
		-- vim.keymap.set('n', 'grn', vim.lsp.buf.rename)
		-- vim.keymap.set('n', 'gra', vim.lsp.buf.code_action)
		-- vim.keymap.set('n', 'grr', vim.lsp.buf.references)
		-- vim.keymap.set('n', 'gri', vim.lsp.buf.implementation)
		-- vim.keymap.set('n', 'gO', vim.lsp.buf.document_symbol)
		-- vim.keymap.set('n', '<C-s>', vim.lsp.buf.signature_help)
		--
	end,
}
