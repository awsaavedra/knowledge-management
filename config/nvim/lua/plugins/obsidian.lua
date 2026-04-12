-- Resolve vault path from the same env var that okm uses.
-- Fallback: sibling directory relative to this config's project root.
local config_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h:h:h")
local vault = vim.env.OBSIDIAN_VAULT
  or (vim.fn.fnamemodify(config_root, ":h") .. "/knowledge-management-system")

return {
  "epwalsh/obsidian.nvim",
  version = "*", -- use latest release, not latest commit
  lazy = true,
  -- Only activate for markdown files that live inside the vault
  event = {
    "BufReadPre "  .. vault .. "/**.md",
    "BufNewFile "  .. vault .. "/**.md",
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {
    workspaces = {
      {
        name = "knowledge",
        path = vault,
      },
    },

    -- Mirror the directory layout used by the okm CLI
    notes_subdir        = "inbox",
    new_notes_location  = "notes_subdir",

    daily_notes = {
      folder       = "daily",
      date_format  = "%Y-%m-%d",
      alias_format = "%B %-d, %Y",
    },

    -- Generate IDs that match okm's slugify() output: kebab-case, no special chars
    note_id_func = function(title)
      if title ~= nil then
        return title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
      end
      -- Fallback for untitled notes: timestamp (matches okm capture format)
      return tostring(os.date("%Y%m%d%H%M%S"))
    end,

    -- Frontmatter structure matches what okm new / okm today write:
    --   title, created (ISO-8601), tags
    note_frontmatter_func = function(note)
      local out = {
        title   = note.title,
        created = os.date("%Y-%m-%dT%H:%M:%S"),
        tags    = note.tags,
      }
      -- Retain any existing metadata fields the note already has
      if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
        for k, v in pairs(note.metadata) do
          out[k] = v
        end
      end
      return out
    end,

    -- Paste images into attachments/ to match the vault layout
    attachments = {
      img_folder = "attachments",
    },

    ui = {
      enable          = true,
      update_debounce = 200,
      checkboxes = {
        [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
        ["x"] = { char = "", hl_group = "ObsidianDone" },
      },
    },
  },

  keys = {
    { "<leader>on", "<cmd>ObsidianNew<cr>",          desc = "New note" },
    { "<leader>oo", "<cmd>ObsidianQuickSwitch<cr>",  desc = "Quick switch" },
    { "<leader>os", "<cmd>ObsidianSearch<cr>",       desc = "Search vault" },
    { "<leader>od", "<cmd>ObsidianToday<cr>",        desc = "Daily note" },
    { "<leader>ob", "<cmd>ObsidianBacklinks<cr>",    desc = "Backlinks" },
    { "<leader>ot", "<cmd>ObsidianTemplate<cr>",     desc = "Insert template" },
    { "<leader>op", "<cmd>ObsidianPasteImg<cr>",     desc = "Paste image" },
    { "<leader>og", "<cmd>ObsidianOpen<cr>",         desc = "Open in Obsidian GUI" },
  },
}
