-- Snacks: loaded early (01- prefix) so its picker is available to other plugins.
vim.pack.add({
  { src = 'https://github.com/nvim-tree/nvim-web-devicons', checkout = 'master' },
  'https://github.com/folke/snacks.nvim',
})

local ok_snacks, snacks = pcall(require, 'snacks')
if ok_snacks then
  ---@type snacks.Config
  snacks.setup {
    explorer = { enabled = true },
    picker = { enabled = true },
    project = {
      dirs = {
        '~/github',
        '~/projects',
        '~/build',
      },
    },
    indent = { enabled = true },
    notifier = { enabled = true },
    statuscolumn = { enabled = true },
    zen = { enabled = true },
  }
end
