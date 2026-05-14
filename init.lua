-- 基础设置
require("options")
require("keymaps")

-- 确保 parser 安装目录在 runtimepath（你原来的需求保留）
local site = vim.fn.stdpath("data") .. "/site"
if not string.find(vim.o.runtimepath, site, 1, true) then
  vim.opt.runtimepath:prepend(site)
end

-- 插件管理（lazy.nvim）
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 启用系统剪切板
vim.opt.clipboard = "unnamedplus"

require("lazy").setup("plugins", {
  ui = { border = "rounded" },
})

-- 桥接 Wayland/X11 剪切板（VMware 兼容）
if vim.fn.has("wsl") == 1 or vim.fn.has("unix") == 1 then
  vim.g.clipboard = {
    name = "myClipboard",
    copy = {
      ["+"] = "xclip -selection clipboard",
      ["*"] = "xclip -selection primary",
    },
    paste = {
      ["+"] = "xclip -selection clipboard -o",
      ["*"] = "xclip -selection primary -o",
    },
    cache_enabled = 1,
  }
end

-- 语言相关 / C++ IDE 功能
require("lsp")
require("cpp_ide")

vim.diagnostic.config({
  virtual_text = true,      -- 行内显示
  signs = true,             -- 左侧符号列
  underline = true,         -- 下划线
  update_in_insert = true,  -- 关键：插入模式也实时更新
  severity_sort = true,
})

local lint = require("lint")
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave", "TextChanged", "TextChangedI" }, {
  callback = function()
    lint.try_lint()
  end,
})

-- 颜色主题
pcall(vim.cmd, "colorscheme dracula")

vim.api.nvim_create_autocmd({ "ColorScheme", "FileType" }, {
  pattern = { "dracula", "cmake" },
  callback = function()
    -- 只改 CMake 变量颜色：如 ${CMAKE_CXX_STANDARD}、${MY_DEFINE}
    vim.api.nvim_set_hl(0, "cmakeVariableValue", { fg = "#FFB86C", bold = true })
    vim.api.nvim_set_hl(0, "cmakeVariableValue", { fg = "#8BE9FD", bold = true })
    vim.api.nvim_set_hl(0, "cmakeVariable", { fg = "#FFB86C", bold = true })
    vim.api.nvim_set_hl(0, "@variable.cmake", { fg = "#FFB86C", bold = true })
    vim.api.nvim_set_hl(0, "@variable.cmake", { fg = "#8BE9FD", bold = true })
  end,
})

-- 注意：这里删除了 vim.g.loaded_nvim_treesitter = 1（这是导致 treesitter not found 的关键问题）

vim.api.nvim_create_autocmd("FileType", {
  pattern = "cmake",
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.expandtab = true
  end,
})

-- 诊断虚拟文本和浮窗内容中英文切换（F1 开关）
local diag_translate_zh = false
local has_translate = vim.fn.executable('trans') == 1
local orig_virtual_text = vim.diagnostic.handlers.virtual_text
local orig_open_float  = vim.diagnostic.open_float

-- 虚拟文本翻译钩子
vim.diagnostic.handlers.virtual_text = {
  show = function(namespace, bufnr, diagnostics, opts)
    if diag_translate_zh and has_translate and #diagnostics > 0 then
      for _, d in ipairs(diagnostics) do
        -- 只在没翻译时翻译，避免重复
        if d.message and not d.message:match("^【已翻译】") then
          local cmd = "trans -b en:zh \"" .. d.message:gsub('["]', "\\\"") .. "\""
          local zh = vim.fn.system(cmd)
          if zh and #zh > 0 then
            d.message = "【已翻译】" .. zh:gsub("\n", "")
          end
        end
      end
    end
    orig_virtual_text.show(namespace, bufnr, diagnostics, opts)
  end,
  hide = orig_virtual_text.hide,
}

-- 浮窗翻译钩子
vim.diagnostic.open_float = function(a, b)
  local bufnr, opts
  if type(a) == "table" and a.bufnr == nil and a.id == nil then
    -- 被 lspconfig 等整合插件以 table 形式调用, 例如 {0, {…}}
    bufnr = a[1]
    opts  = a[2]
  elseif type(a) == "table" and a.bufnr then
    -- Native 命名参数形式
    bufnr = a.bufnr
    opts  = a
  else
    -- (bufnr, opts) 传统调用
    bufnr = a
    opts  = b
  end
  -- fallback: 当前缓冲区号
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local diagnostics = vim.diagnostic.get(bufnr)
  if diag_translate_zh and has_translate and #diagnostics > 0 then
    for _, d in ipairs(diagnostics) do
      if d.message and not d.message:match("^【已翻译】") then
        local cmd = "trans -b en:zh \"" .. d.message:gsub('["]', "\\\"") .. "\""
        local zh = vim.fn.system(cmd)
        if zh and #zh > 0 then
          d.message = "【已翻译】" .. zh:gsub("\n", "")
        end
      end
    end
  end
  orig_open_float(bufnr, opts)
end

-- 强制刷新诊断（用于切换时整屏渲染一次）
local function refresh_diagnostic_virtual_text(bufnr)
  vim.diagnostic.show(nil, bufnr or 0)
end

-- F1 开关：虚拟文本 + 浮窗诊断中英文翻译切换
vim.keymap.set("n", "<F1>", function()
  diag_translate_zh = not diag_translate_zh
  vim.notify("诊断翻译已" .. (diag_translate_zh and "开启" or "关闭"), vim.log.levels.INFO)
  vim.cmd("redraw")  -- 防止 notify 卡屏
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    refresh_diagnostic_virtual_text(buf)
  end
end, { noremap = true, desc = "诊断翻译中/英文切换" })

-- 默认开启 inlay hints + F4 开关（兼容 0.10/0.11/0.12）
local inlay_enabled = true

local function set_inlay_hint(buf, enabled)
  if vim.lsp.inlay_hint and vim.lsp.inlay_hint.enable then
    -- 0.12+ 新签名: enable(boolean, {bufnr=...})
    local ok = pcall(vim.lsp.inlay_hint.enable, enabled, { bufnr = buf })
    if not ok then
      -- 兼容旧签名: enable(bufnr, boolean)
      pcall(vim.lsp.inlay_hint.enable, buf, enabled)
    end
  elseif vim.lsp.buf.inlay_hint then
    vim.lsp.buf.inlay_hint(buf, enabled)
  end
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    set_inlay_hint(args.buf, inlay_enabled)
  end,
})

vim.keymap.set("n", "<F4>", function()
  inlay_enabled = not inlay_enabled
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    set_inlay_hint(buf, inlay_enabled)
  end
  vim.notify("Inlay hints 已" .. (inlay_enabled and "开启" or "关闭"), vim.log.levels.INFO)
end, { desc = "Toggle inlay hints" })
