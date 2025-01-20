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
	},
	keys = {
		{ "<space>uus", ":SessionSearch<CR>" },
	},
}
