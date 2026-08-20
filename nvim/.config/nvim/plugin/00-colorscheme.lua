-- Colorscheme: loaded first (00- prefix) to avoid flash of default colors.
vim.pack.add({
  'https://github.com/ellisonleao/gruvbox.nvim',
  'https://github.com/rebelot/kanagawa.nvim', -- keeping as backup
})

local ok, gruvbox = pcall(require, 'gruvbox')
if ok then
  gruvbox.setup({
    terminal_colors = true, -- add neovim terminal colors
    undercurl = true,
    underline = true,
    bold = true,
    italic = {
      strings = true,
      emphasis = true,
      comments = true,
      operators = false,
      folds = true,
    },
    strikethrough = true,
    invert_selection = false,
    invert_signs = false,
    invert_tabline = false,
    invert_intend_guides = false,
    inverse = true, -- invert background for search, highlight, statusline and errors
    contrast = "", -- can be "hard", "soft" or empty string
    palette_overrides = {},
    overrides = {},
    transparent_mode = true, -- This handles most transparency
  })

  vim.cmd.colorscheme('gruvbox')

  -- Force transparency for specific groups if transparent_mode isn't enough
  local function set_transparency()
    local groups = {
      "Normal", "NormalFloat", "NormalNC", "SignColumn", "FoldColumn",
      "StatusLine", "StatusLineNC", "WinSeparator", "VertSplit",
      "EndOfBuffer", "MsgArea", "Pmenu", "NormalFloat"
    }
    for _, group in ipairs(groups) do
      vim.api.nvim_set_hl(0, group, { bg = "NONE", ctermbg = "NONE" })
    end
  end

  set_transparency()
  
  -- Re-apply on colorscheme change (if switched manually)
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = set_transparency,
  })
end
