; Overrides nvim-treesitter's markdown_inline injections. Latex is injected
; only when the buffer opts in (see lua/config/md-math.lua, <space><space>tm).

((html_tag) @injection.content
  (#set! injection.language "html")
  (#set! injection.combined))

((latex_block) @injection.content
  (#set-md-math-lang!)
  (#set! injection.include-children))
