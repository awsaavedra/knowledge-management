return {
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      signs = true,
      keywords = {
        TODO  = { icon = " ", color = "todo_yellow", alt = {} },
        FIXME = { icon = " ", color = "todo_orange", alt = {} },
        BUG   = { icon = " ", color = "todo_red",    alt = { "BUGFIX", "ISSUE" } },
      },
      colors = {
        todo_yellow = { "#FFD700" },
        todo_orange = { "#FF8C00" },
        todo_red    = { "#FF3030" },
      },
      highlight = {
        keyword = "wide",
        pattern = [[.*<(KEYWORDS)\s*:]],
      },
      search = {
        pattern = [[\b(KEYWORDS):]],
      },
    },
  },
}
