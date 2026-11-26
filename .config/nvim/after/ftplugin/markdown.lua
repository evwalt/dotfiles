-- local set = vim.opt_local

-- set.textwidth = 80

-- Work-hour sums on weekday headings; only active in files containing the marker `<!-- agenda-sums -->`
require("config.agenda-sums").attach(vim.api.nvim_get_current_buf())

-- Path-only comment lines shown as file names; only active in files containing `<!-- path-names -->`
require("config.path-names").attach(vim.api.nvim_get_current_buf())
