local map = vim.keymap.set
local opts = { noremap = true, silent = true }

vim.g.mapleader = " "

map("n", "<F2>", ":NvimTreeToggle<CR>", opts)
map("n", "<F3>", "<cmd>AerialToggle!<CR>", opts)

map("n", "<F8>", vim.diagnostic.goto_next, opts)
map("n", "<S-F8>", vim.diagnostic.goto_prev, opts)

map("n", "<C-p>", "<cmd>Telescope find_files<CR>", opts)
map("n", "<C-f>", "<cmd>Telescope live_grep<CR>", opts)
map("n", "<C-b>", "<cmd>Telescope buffers<CR>", opts)
map("n", "<leader>fc", "<cmd>Telescope commands<CR>", opts)
map("n", "<leader>fh", "<cmd>Telescope oldfiles<CR>", opts)

map("n", "<F5>", ":lua require('cpp_ide').SmartCompileAndRun()<CR>", opts)
map("n", "<F6>", ":lua require('cpp_ide').SmartCompileOnly()<CR>", opts)
map("n", "<C-F5>", ":lua require('cpp_ide').CleanBuild()<CR>", opts)
map("n", "<F9>", ":lua require('cpp_ide').QuickClean()<CR>", opts)
map("n", "<leader>dc", ":lua require('cpp_ide').DebugCMake()<CR>", opts)

map("n", "<C-h>", "<C-w>h", opts)
map("n", "<C-j>", "<C-w>j", opts)
map("n", "<C-k>", "<C-w>k", opts)
map("n", "<C-l>", "<C-w>l", opts)
map("n", "<leader>wv", ":vsplit<CR>", opts)
map("n", "<leader>wh", ":split<CR>", opts)
map("n", "<leader>wc", ":close<CR>", opts)
map("n", "<leader>wo", ":only<CR>", opts)

map("n", "<C-s>", ":w<CR>", opts)
map("i", "<C-s>", "<Esc>:w<CR>a", opts)
map("n", "<leader>q", ":q<CR>", opts)
map("n", "<leader>qq", ":q!<CR>", opts)
map("n", "<leader>wq", ":wq<CR>", opts)

map("n", "\\", function() require("Comment.api").toggle.linewise.current() end, opts)
map("v", "\\", function()
  local esc = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
  vim.api.nvim_feedkeys(esc, "nx", false)
  require("Comment.api").toggle.linewise(vim.fn.visualmode())
end, opts)

map("n", "<leader>ss", ":%s///g<Left><Left><Left>", { noremap = true })
map("n", "<leader>sc", ":nohlsearch<CR>", opts)

map("n", "<leader>ev", ":vsplit $MYVIMRC<CR>", opts)
map("n", "<leader>sv", ":source $MYVIMRC<CR>", opts)

map("n", "Y", "y$", opts)
map("n", "<leader>p", '"+p', opts)
map("v", "<leader>y", '"+y', opts)
map("n", "<leader>d", '"_d', opts)
map("v", "<leader>d", '"_d', opts)

map("n", "<leader>tn", ":tabnew<CR>", opts)
map("n", "<leader>tc", ":tabclose<CR>", opts)
map("n", "<leader>th", ":tabprev<CR>", opts)
map("n", "<leader>tl", ":tabnext<CR>", opts)
map("n", "<leader>t1", ":tabn 1<CR>", opts)
map("n", "<leader>t2", ":tabn 2<CR>", opts)

map("n", "<F7>", function()
  -- 尝试在已有终端之间切换；如果没有终端，则打开新的
  local bufs = vim.api.nvim_list_bufs()
  for _, b in ipairs(bufs) do
    if vim.bo[b].buftype == "terminal" then
      -- 如果已经有终端 buffer，就切过去
      vim.api.nvim_set_current_buf(b)
      return
    end
  end
  -- 没有终端，就创建一个在底部
  vim.cmd("belowright split")
  vim.cmd("resize 6")
  vim.cmd("terminal")
end, opts)

map("t", "<Esc>", [[<C-\><C-n>]], opts)
map("t", "<C-w>h", [[<C-\><C-n><C-w>h]], opts)
map("t", "<C-w>j", [[<C-\><C-n><C-w>j]], opts)
map("t", "<C-w>k", [[<C-\><C-n><C-w>k]], opts)
map("t", "<C-w>l", [[<C-\><C-n><C-w>l]], opts)
map("t", "jk", [[<C-\><C-n>]], opts)
