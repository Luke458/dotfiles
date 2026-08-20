local map = vim.keymap.set
local opts = { silent = true }

local function url_in_line_at_col(line, col)
  if not line or line == '' or not col or col < 1 then
    return nil
  end

  local from = 1
  while true do
    local s, e = line:find('https?://%S+', from)
    if not s then
      return nil
    end

    if col >= s and col <= e then
      local url = line:sub(s, e)
      -- Trim punctuation that commonly trails URLs in prose/markdown.
      url = url:gsub('[%]%)%}%.,;:!%?"' .. "'" .. ']+$', '')
      return url ~= '' and url or nil
    end

    from = e + 1
  end
end

-- ============================================================
-- [[ Window Navigation & Resize ]]
-- ============================================================
map('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus left' })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus down' })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus up' })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus right' })
map('n', '<C-Up>', ':resize -2<CR>', opts)
map('n', '<C-Down>', ':resize +2<CR>', opts)
map('n', '<C-Left>', ':vertical resize -2<CR>', opts)
map('n', '<C-Right>', ':vertical resize +2<CR>', opts)

-- ============================================================
-- [[ Buffer & Tab Navigation ]]
-- ============================================================
map('n', '<S-l>', '<cmd>BufferLineCycleNext<CR>', { desc = 'Next buffer' })
map('n', '<S-h>', '<cmd>BufferLineCyclePrev<CR>', { desc = 'Prev buffer' })
map('n', '<leader>x', '<cmd>bdelete<CR>', { desc = 'Close buffer' })
map('n', '<S-q>', '<cmd>bdelete!<CR>', { silent = true, desc = 'Force close buffer' })

map('n', '<Leader>1', '1gt', { silent = true, desc = 'Go to tab 1' })
map('n', '<Leader>2', '2gt', { silent = true, desc = 'Go to tab 2' })
map('n', '<Leader>3', '3gt', { silent = true, desc = 'Go to tab 3' })
map('n', '<Leader>4', '4gt', { silent = true, desc = 'Go to tab 4' })
map('n', '<Leader>5', '5gt', { silent = true, desc = 'Go to tab 5' })
map('n', '<Leader>t', '<cmd>tabnew<CR>', { silent = true, desc = 'New tab' })
map('n', '<A-q>', '<cmd>tabclose<CR>', { silent = true, desc = 'Close tab' })

-- ============================================================
-- [[ File Navigation ]]
-- ============================================================
map('n', '-', '<cmd>Oil<CR>', { desc = 'Open parent directory (oil)' })
map('n', '<leader>o', function() require('oil').toggle_float() end, { desc = 'Toggle oil float' })
map('n', '<leader>fe', function() Snacks.explorer.open() end, { desc = '[F]iles [E]xplorer' })
map('n', '<leader>ff', function() Snacks.picker.smart() end, { desc = 'Smart [F]ile picker' })
map('n', '<leader>sf', function() Snacks.picker.files() end, { desc = '[S]earch [F]iles' })
map('n', '<leader>fp', function() Snacks.picker.projects() end, { desc = 'Browse [P]rojects' })

-- ============================================================
-- [[ Search (Snacks Picker) ]]
-- ============================================================
map('n', '<leader>sh', function() Snacks.picker.help() end, { desc = '[S]earch [H]elp' })
map('n', '<leader>sk', function() Snacks.picker.keymaps() end, { desc = '[S]earch [K]eymaps' })
map('n', '<leader>sc', function() Snacks.picker.commands() end, { desc = '[S]earch [C]ommands' })
map('n', '<leader>sb', function() Snacks.picker.builtin() end, { desc = '[S]earch [B]uiltins' })
map('n', '<leader>ss', function() Snacks.picker.pickers() end, { desc = '[S]elect Snacks picker' })
map({ 'n', 'x' }, '<leader>sw', function() Snacks.picker.grep_word() end, { desc = '[S]earch current [W]ord' })
map('n', '<leader>fg', function() Snacks.picker.grep() end, { desc = '[S]earch by [G]rep' })
map('n', '<leader>sd', function() Snacks.picker.diagnostics() end, { desc = '[S]earch [D]iagnostics' })
map('n', '<leader>sr', function() Snacks.picker.resume() end, { desc = '[S]earch [R]esume' })
map('n', '<leader>s.', function() Snacks.picker.recent() end, { desc = '[S]earch Recent Files' })
map('n', '<leader><leader>', function() Snacks.picker.buffers() end, { desc = 'Switch Buffers' })
map('n', '<leader>s/', function() Snacks.picker.lines {} end, { desc = 'Fuzzy search in buffer' })
map('n', '<leader>sn', function() Snacks.picker.files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })

-- ============================================================
-- [[ LSP & Diagnostics ]]
-- ============================================================
map('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
map('n', '<leader>xx', '<cmd>Trouble diagnostics toggle<CR>', { desc = 'Diagnostics (Trouble)' })
map('n', '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<CR>', { desc = 'Buffer Diagnostics' })
map('n', '<leader>cs', '<cmd>Trouble symbols toggle<CR>', { desc = 'Symbols (Trouble)' })
map('n', '<leader>v', '<cmd>AerialToggle!<CR>', { desc = 'Toggle outline [V]iew' })
map('n', '<leader>=', function() require('conform').format { async = true, lsp_format = 'fallback' } end, { desc = '[=] Format buffer' })

-- ============================================================
-- [[ Terminal ]]
-- ============================================================
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
map('n', '<C-`>', function()
  local dir = vim.fn.expand '%:p:h'
  if dir == '' or vim.fn.isdirectory(dir) == 0 then
    local cwd = vim.uv.cwd()
    dir = cwd or '.'
  end
  vim.cmd('ToggleTerm dir=' .. vim.fn.fnameescape(dir))
end, { desc = 'Toggle terminal' })
map('n', '<C-\\>', function() Snacks.zen() end, { desc = 'Toggle Zen mode' })

-- ============================================================
-- [[ Editing ]]
-- ============================================================
map('i', 'jj', '<ESC>', { silent = true, desc = 'Exit insert mode' })
map('v', 'p', '"_dP', { silent = true, desc = 'Paste without overwriting clipboard' })
map('v', '<', '<gv', { silent = true, desc = 'Dedent and stay in visual mode' })
map('v', '>', '>gv', { silent = true, desc = 'Indent and stay in visual mode' })
map('n', '<leader>e', '$', { silent = true, desc = 'Jump to [E]nd of line' })
map('n', 'S', ':%s//g<Left><Left>', { desc = 'Search and replace in buffer' })
map('n', '<leader>y', function()
  local node = vim.treesitter.get_node()
  while node and node:type() ~= 'fenced_code_block' do
    node = node:parent()
  end
  if not node then
    vim.notify('Not inside a fenced code block', vim.log.levels.WARN)
    return
  end
  for child in node:iter_children() do
    if child:type() == 'code_fence_content' then
      local text = vim.treesitter.get_node_text(child, 0)
      vim.fn.setreg('+', text)
      vim.fn.setreg('"', text)
      vim.notify('Code block copied to clipboard', vim.log.levels.INFO)
      return
    end
  end
end, { desc = '[Y]ank fenced code block' })

-- ============================================================
-- [[ Comments ]]
-- ============================================================
-- We try to map <leader>/ to comments. 
-- Since this file is loaded after plugins in init.lua, 
-- we can check if Comment.nvim or builtin is active.
map('n', '<leader>/', 'gcc', { remap = true, desc = 'Toggle comment' })
map('x', '<leader>/', 'gc', { remap = true, desc = 'Toggle comment' })

-- ============================================================
-- [[ AI (Copilot) ]]
-- ============================================================
map({ 'n', 'v' }, '<leader>cc', function() require('CopilotChat').toggle() end, { desc = '[C]opilot [C]hat toggle' })
map({ 'n', 'v' }, '<leader>cq', function()
  local input = vim.fn.input 'Quick Chat: '
  if input ~= '' then
    require('CopilotChat').ask(input, { resources = 'selection' })
  end
end, { desc = '[C]opilot [Q]uick Chat' })
map('n', '<leader>cp', '<cmd>CopilotChatPrompts<CR>', { desc = '[C]opilot [P]rompts' })
map('n', '<leader>cm', '<cmd>CopilotChatModels<CR>', { desc = '[C]opilot [M]odels' })
map('n', '<leader>cr', '<cmd>CopilotChatReset<CR>', { desc = '[C]opilot [R]eset chat' })

-- ============================================================
-- [[ Tools & Plugins ]]
-- ============================================================
map('n', '<leader>a', ':Alpha<CR>', { silent = true, desc = 'Open [A]lpha dashboard' })
map('n', '<leader>p', '<cmd>PasteImage<CR>', { silent = true, desc = '[P]aste image from clipboard' })
map('n', '<F5>', '<cmd>UndotreeToggle<CR><cmd>UndotreeFocus<CR>', { silent = true, desc = 'Toggle Undotree' })
map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlights' })

-- URL Opener
map('n', '<LeftMouse>', function()
  local m = vim.fn.getmousepos()
  if m.winid and m.winid ~= 0 and m.line and m.column and m.line > 0 and m.column > 0 then
    local ok_buf, bufnr = pcall(vim.api.nvim_win_get_buf, m.winid)
    if ok_buf and bufnr then
      local ok_line, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, m.line - 1, m.line, false)
      if ok_line then
        local target = url_in_line_at_col(lines[1] or '', m.column)
        if target then
          vim.ui.open(target)
          return
        end
      end
    end
  end
  vim.api.nvim_feedkeys(vim.keycode '<LeftMouse>', 'n', false)
end, { desc = 'Click URL to open' })
