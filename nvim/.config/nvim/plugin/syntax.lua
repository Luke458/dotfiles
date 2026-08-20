-- Treesitter context UI on top of Neovim 0.12 built-in treesitter.

vim.pack.add({
  'https://github.com/nvim-treesitter/nvim-treesitter',
  'https://github.com/nvim-treesitter/nvim-treesitter-context',
})

-- Treesitter
local ok_ts, ts = pcall(require, 'nvim-treesitter.configs')
if ok_ts then
  ---@diagnostic disable-next-line: missing-fields
  ts.setup {
    ensure_installed = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' },
    auto_install = true,
    highlight = { enable = true },
    indent = { enable = true },
  }
end

local ok_ctx, ctx = pcall(require, 'treesitter-context')
if ok_ctx then
  ctx.setup { max_lines = 3 }
end