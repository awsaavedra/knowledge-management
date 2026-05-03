-- Add <Up>/<Down> to blink.cmp's keymap so arrow keys navigate completion
-- popups (including the noice.nvim cmdline popup, e.g. on `:qui<Tab>`).
-- LazyVim's defaults (<C-n>/<C-p>/<Tab>) still work — these are additive.

return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      ["<Down>"] = { "select_next", "fallback" },
      ["<Up>"] = { "select_prev", "fallback" },
    },
  },
}
