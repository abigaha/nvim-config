-- ~/.config/nvim/lua/options.lua

local opt = vim.opt
local g   = vim.g

opt.compatible   = false
opt.encoding     = "utf-8"
opt.fileencoding = "utf-8"
opt.termguicolors = true
opt.background    = "dark"

opt.number = true
-- opt.relativenumber = true
opt.cursorline = true
opt.showcmd = true
opt.laststatus = 2

opt.autoindent  = true
opt.smartindent = true
opt.expandtab   = true
opt.tabstop     = 2
opt.shiftwidth  = 2
opt.softtabstop = 2

opt.incsearch = true
opt.hlsearch  = true
opt.ignorecase = true
opt.smartcase  = true

opt.backspace = { "indent", "eol", "start" }
opt.hidden    = true
opt.mouse     = "a"
opt.clipboard = "unnamedplus"

g.gruvbox_contrast_dark = "hard"

opt.backup      = true
opt.writebackup = true
opt.backupcopy  = "auto"
opt.backupdir   = vim.fn.expand("~/.vim/backup//")
opt.directory   = vim.fn.expand("~/.vim/swap//")
opt.undodir     = vim.fn.expand("~/.vim/undo//")
opt.undofile    = true
opt.backupskip  = { "/tmp/*", "/private/tmp/*" }

local function ensure_dir(dir)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p", 0x1C0) -- 0700
  end
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    ensure_dir(vim.o.backupdir)
    ensure_dir(vim.o.directory)
    ensure_dir(vim.o.undodir)
  end,
})

-- 主题
-- vim.cmd("colorscheme gruvbox")
