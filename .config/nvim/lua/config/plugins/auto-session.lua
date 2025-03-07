return {
	"rmagatti/auto-session",
	lazy = false,

	---enables autocomplete for opts
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {
		-- suppressed_dirs = { '~/', '~/Projects', '~/Downloads', '/' },
		-- log_level = 'debug',
		-- auto_restore_last_session = true,
		show_auto_restore_notif = true,
		session_lens = {
			theme_conf = {
				layout_config = {
					-- As one example, can change width/height of picker
					-- width = 0.8,    -- percent of window
					width = { padding = 2 }, -- percent of window
					-- height = 0.5,
				},
			},
		},
	},
	keys = {
		{ "<space>uus", ":SessionSearch<CR>" },
	},
}
