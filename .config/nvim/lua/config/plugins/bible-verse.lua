return {
	"anthony-halim/bible-verse.nvim",
	-- Lazy load on plugin commands
	cmd = { "BibleVerse", "BibleVerseQuery", "BibleVerseInsert" },
	dependencies = {
		"MunifTanjim/nui.nvim",
	},
	opts = {
		diatheke = {
			-- (MANDATORY)
			-- Corresponds to the diatheke module; diatheke's -b flag.
			-- In this example, we are using KJV module.
			translation = "KJV",
		},
	},
	-- plugin is not set up by default
	config = true,
}
