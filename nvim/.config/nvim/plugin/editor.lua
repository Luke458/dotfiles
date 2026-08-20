-- Editor utilities: autopairs, indent guides, linting, highlighting, auto-save,
-- guess-indent, todo-comments, img-clip, undotree, wakatime, suda, visual-multi,
-- grammarly LSP.

vim.pack.add({
  -- Autopairs
  'https://github.com/windwp/nvim-autopairs',
  -- Indent guides
  'https://github.com/lukas-reineke/indent-blankline.nvim',
  -- Linting
  'https://github.com/mfussenegger/nvim-lint',
  -- Color highlighting
  'https://github.com/brenoprata10/nvim-highlight-colors',
  -- Auto-save
  'https://github.com/Pocco81/auto-save.nvim',
  -- Auto-detect tab/space indentation
  'https://github.com/NMAC427/guess-indent.nvim',
  -- Todo comment highlights
  'https://github.com/folke/todo-comments.nvim',
  -- Paste images from clipboard into Markdown
  'https://github.com/HakonHarnes/img-clip.nvim',
  -- Persistent undo history tree (mapped to <F5>)
  'https://github.com/mbbill/undotree',
  -- Edit files as sudo (:SudaWrite)
  'https://github.com/lambdalisue/suda.vim',
  -- Multi-cursor (Ctrl+N)
  { src = 'https://github.com/mg979/vim-visual-multi', checkout = 'master' },
  -- Grammarly LSP for prose
  'https://github.com/emacs-grammarly/lsp-grammarly',
  -- F# language support
  'https://github.com/ionide/Ionide-vim',
  -- Smart comment toggling
  'https://github.com/numToStr/Comment.nvim',
})

-- autopairs
local ok_ap, ap = pcall(require, 'nvim-autopairs')
if ok_ap then ap.setup {} end

-- indent-blankline
local ok_ibl, ibl = pcall(require, 'ibl')
if ok_ibl then ibl.setup {} end

-- nvim-lint
local ok_lint, lint = pcall(require, 'lint')
if ok_lint then
  lint.linters_by_ft = {
    markdown = { 'markdownlint-cli2' },
  }
  local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
    group = lint_augroup,
    callback = function()
      if vim.bo.modifiable then
        lint.try_lint()
      end
    end,
  })
end

-- nvim-highlight-colors
local ok_hc, hc = pcall(require, 'nvim-highlight-colors')
if ok_hc then hc.setup { render = 'background' } end

-- auto-save
local ok_as, as = pcall(require, 'auto-save')
if ok_as then as.setup {} end

-- guess-indent
local ok_gi, gi = pcall(require, 'guess-indent')
if ok_gi then gi.setup {} end

-- todo-comments
local ok_todo, todo = pcall(require, 'todo-comments')
if ok_todo then todo.setup { signs = false } end

-- Comment.nvim
local ok_com, com = pcall(require, 'Comment')
if ok_com then com.setup() end

-- img-clip
local ok_ic, ic = pcall(require, 'img-clip')
if ok_ic then
  ic.setup {
    default = {
      dir_path = function()
        return vim.fn.expand '~/Pictures/neovim-images/' .. os.date '%Y' .. '/'
      end,
      extension = 'webp',
      process_cmd = 'cwebp -quiet -q 80 -o - -- - 2>/dev/null',
      template = '![$FILE_NAME_NO_EXT]($FILE_PATH)',
      relative_template_path = true,
    },
  }
end
