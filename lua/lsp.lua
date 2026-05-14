local cmp = require("cmp")
local luasnip = require("luasnip")

-- =========================
-- nvim-cmp 配置
-- =========================
cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = {
    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  },
  sources = {
    { name = "nvim_lsp" },
    { name = "luasnip" },
  },
})

-- =========================
-- 使用 Neovim 内建 LSP 启动 clangd（不依赖 nvim-lspconfig）
-- =========================

-- 自动为所有 C / C++ buffer 启动 clangd
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp", "objc", "objcpp" },
  callback = function(args)
    -- 如果当前 buffer 已经有 clangd client 附着，就不要重复启动
    local bufnr = args.buf
    local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
    for _, c in ipairs(clients) do
      if c.name == "clangd" then
        return
      end
    end

    vim.lsp.start({
      name = "clangd",
      cmd = {
      "clangd",
      "--background-index",
      "--clang-tidy",  -- 启用 clang-tidy
      "--header-insertion=iwyu",  -- 可选：智能头文件插入
      "--completion-style=detailed",  -- 可选：详细补全
      },
    root_dir = vim.fs.dirname(vim.fs.find({ "compile_commands.json", "CMakeLists.txt", ".git" }, { upward = true })[1])
    or vim.loop.cwd(),
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
    })
  end,
})

-- =========================
-- CMake LSP 配置 (neocmakelsp)
-- =========================
vim.api.nvim_create_autocmd("FileType", {
  pattern = "cmake",
  callback = function(args)
    local bufnr = args.buf
    local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
    for _, c in ipairs(clients) do
      if c.name == "neocmakelsp" then return end
    end

    -- 查找我们刚才下载的 neocmakelsp
    local cmd_path = vim.fn.expand("~/.local/bin/neocmakelsp")
    if vim.fn.executable(cmd_path) == 0 then
      -- 也可以尝试去系统 PATH 找
      cmd_path = "neocmakelsp"
    end

    if vim.fn.executable(cmd_path) == 1 then
      vim.lsp.start({
        name = "neocmakelsp",
        -- neocmakelsp 需要加上 --stdio 参数
        cmd = { cmd_path, "stdio"},
        root_dir = vim.fs.dirname(vim.fs.find({ "CMakeLists.txt", ".git" }, { upward = true })[1])
          or vim.loop.cwd(),
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })
    else
      vim.notify("未找到 neocmakelsp，请确认是否已下载", vim.log.levels.WARN)
    end
  end,
})
-- LSP 键位（与原来 coc 类似）
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

map("n", "gd", vim.lsp.buf.definition, opts)
map("n", "gr", vim.lsp.buf.references, opts)
map("n", "gi", vim.lsp.buf.implementation, opts)
map("n", "gy", vim.lsp.buf.type_definition, opts)
map("n", "K", vim.lsp.buf.hover, opts)
map("n", "<leader>rn", vim.lsp.buf.rename, opts)
map("n", "<leader>ca", vim.lsp.buf.code_action, opts)

-- 自动显示诊断浮动窗口（每次停留都刷新）
vim.o.updatetime = 1000
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    local has_float = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative == "cursor" then
        has_float = true
        break
      end
    end
    if not has_float then
      vim.diagnostic.open_float({ focus = false })
    end
  end,
})
