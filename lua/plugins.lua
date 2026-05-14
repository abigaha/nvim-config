return {
  -- 颜色主题（包括你原来的 gruvbox）
  { "morhetz/gruvbox" },
  { "dracula/vim", name = "dracula" },
  { "altercation/vim-colors-solarized" },
  { "joshdick/onedark.vim" },
  { "arcticicestudio/nord-vim" },

  -- 文件树
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({})
    end,
  },

  -- 状态栏
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = { theme = "gruvbox" },
      })
    end,
  },

  -- 缩进线
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {},
  },

  -- 注释
  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
  },

  -- 自动格式化（C/C++/CMake）
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    config = function()
      -- 默认的 .clang-format 内容
      local default_clang_format = [[
---
Language: Cpp
BasedOnStyle: Google
IndentWidth: 2
TabWidth: 2
UseTab: Never
ColumnLimit: 100
AccessModifierOffset: -2
AlignAfterOpenBracket: Align
AlignConsecutiveAssignments: false
AlignConsecutiveDeclarations: false
AlignOperands: true
AlignTrailingComments: true
AllowShortBlocksOnASingleLine: false
AllowShortFunctionsOnASingleLine: Inline
AllowShortIfStatementsOnASingleLine: false
AllowShortLoopsOnASingleLine: false
BinPackArguments: true
BinPackParameters: true
BreakBeforeBraces: Attach
BreakConstructorInitializers: BeforeColon
IncludeBlocks: Regroup
IndentCaseLabels: true
NamespaceIndentation: None
PointerAlignment: Left
SortIncludes: true
SortUsingDeclarations: true
SpaceAfterCStyleCast: false
SpaceAfterTemplateKeyword: true
SpaceBeforeAssignmentOperators: true
SpaceBeforeParens: ControlStatements
SpacesInAngles: false
SpacesInContainerLiterals: false
SpacesInParentheses: false
SpacesInSquareBrackets: false
Standard: Latest
...
]]

      -- 查找项目根目录
      local function find_project_root()
        local markers = { "CMakeLists.txt", ".git", "Makefile", "compile_commands.json" }
        local found = vim.fs.find(markers, { upward = true })[1]
        if found then
          return vim.fs.dirname(found)
        end
        return vim.fn.getcwd()
      end

      -- 保存前自动创建 .clang-format（仅 C/C++ 文件）
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = { "*.c", "*.cpp", "*.h", "*.hpp", "*.cc", "*.cxx" },
        callback = function()
          local root = find_project_root()
          local cf_path = root .. "/.clang-format"
          if vim.fn.filereadable(cf_path) == 0 then
            local f = io.open(cf_path, "w")
            if f then
              f:write(default_clang_format)
              f:close()
              vim.notify("已自动创建 " .. cf_path, vim.log.levels.INFO)
            end
          end
        end,
      })

      require("conform").setup({
        formatters_by_ft = {
          c = { "clang-format" },
          cpp = { "clang-format" },
          objc = { "clang-format" },
          cmake = { "cmake_format" },
        },
        format_on_save = {
          timeout_ms = 3000,
          lsp_fallback = true,
        },
      })

      -- 手动格式化键绑定
      vim.keymap.set("n", "<leader>f", function()
        require("conform").format()
      end, { noremap = true, silent = true, desc = "Format file" })
    end,
  },

  -- CMake lint（语法/风格检查）
  {
    "mfussenegger/nvim-lint",
    config = function()
      local lint = require("lint")

      -- 优先使用系统 PATH 的 cmakelint，找不到就尝试 ~/.local/bin/cmakelint
      local cmakelint_cmd = "cmakelint"
      if vim.fn.executable(cmakelint_cmd) == 0 then
        local user_cmd = vim.fn.expand("~/.local/bin/cmakelint")
        if vim.fn.executable(user_cmd) == 1 then
          cmakelint_cmd = user_cmd
        end
      end

      -- 配置 cmakelint 可执行文件路径
      if lint.linters.cmakelint then
        lint.linters.cmakelint.cmd = cmakelint_cmd
        lint.linters.cmakelint.args = {
          "--filter=-whitespace/indent",
          "--",
        }
      end

      lint.linters_by_ft = {
        cmake = { "cmakelint" },
      }

      -- 保存后运行 lint（仅在 cmakelint 可用时）
      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = { "CMakeLists.txt", "*.cmake" },
        callback = function()
          if vim.fn.executable(cmakelint_cmd) == 1 then
            lint.try_lint()
          else
            vim.notify(
              "cmakelint 未安装（请执行: pipx install cmakelint）",
              vim.log.levels.WARN
            )
          end
        end,
      })
    end,
  },

  -- Telescope 模糊搜索
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.6",
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local ok, configs = pcall(require, "nvim-treesitter.configs")
      if not ok then
        return
      end

      configs.setup({
        ensure_installed = { "lua", "vim", "vimdoc", "c", "cpp", "cmake", "markdown", "markdown_inline" },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- 补全
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "L3MON4D3/LuaSnip" },
  { "saadparwaiz1/cmp_luasnip" },

  -- Copilot core
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = {
          enabled = true,
          auto_trigger = true,
          keymap = {
            accept = "<M-l>",
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
        panel = {
          enabled = true,
          auto_refresh = false,
          keymap = {
            jump_prev = "[[",
            jump_next = "]]",
            accept = "<CR>",
            open = "<M-CR>",
          },
        },
        filetypes = {
          ["*"] = true,
        },
      })
    end,
  },

  -- Copilot Chat
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim" },
    },
    build = "make tiktoken",
    opts = {
      debug = false,
      model = "gpt-4o",
      temperature = 0.1,
      window = {
        layout = "float",
        relative = "editor",
        border = "rounded",
        width = 0.8,
        height = 0.6,
      },
      mappings = {
        close = "q",
        submit_prompt = "<C-s>",
      },
    },
    keys = {
      { "<leader>cc", ":CopilotChat<CR>", mode = { "n", "v" }, desc = "Copilot Chat" },
      { "<leader>ce", ":CopilotChatExplain<CR>", mode = { "n", "v" }, desc = "Explain code" },
      { "<leader>ct", ":CopilotChatTests<CR>", mode = { "n", "v" }, desc = "Generate tests" },
      { "<leader>cf", ":CopilotChatFix<CR>", mode = { "n", "v" }, desc = "Fix code" },
      { "<leader>cm", ":CopilotChatModels<CR>", mode = { "n", "v" }, desc = "Models" },
    },
  },

  -- 符号大纲
  {
    "stevearc/aerial.nvim",
    config = function()
      require("aerial").setup({
        layout = {
          width = 35,
          default_direction = "right",
        },
        show_guides = true,
        filter_kind = false,
      })
    end,
  },

}
