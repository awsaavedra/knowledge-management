-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- --- Public/Private PARA banner ---
-- Sets a colored winbar based on the buffer's path:
--   * red  "⚠ PRIVATE PARA · <subdir>"  when path matches private-*/
--   * green "PUBLIC PARA · <subdir>"     when path matches a public PARA folder
-- Empty otherwise (config files, scratch buffers, etc.).

vim.api.nvim_set_hl(0, "KMBannerPublic",  { fg = "#000000", bg = "#7CB342", bold = true })
vim.api.nvim_set_hl(0, "KMBannerPrivate", { fg = "#FFFFFF", bg = "#C62828", bold = true })

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  group = vim.api.nvim_create_augroup("KMBanner", { clear = true }),
  callback = function(args)
    local path = vim.api.nvim_buf_get_name(args.buf)
    if path == "" then
      vim.opt_local.winbar = ""
      return
    end
    local private_sub = path:match("/(private%-[^/]+)/")
    if private_sub then
      vim.opt_local.winbar = "%#KMBannerPrivate# ⚠ PRIVATE PARA · " .. private_sub .. " %*"
      return
    end
    local public_sub = path:match("/(daily)/")
                    or path:match("/(inbox)/")
                    or path:match("/(attachments)/")
                    or path:match("/(archive)/")
    if public_sub then
      vim.opt_local.winbar = "%#KMBannerPublic# PUBLIC PARA · " .. public_sub .. " %*"
      return
    end
    vim.opt_local.winbar = ""
  end,
})
