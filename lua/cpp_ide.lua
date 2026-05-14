local M = {}

-- 在底部终端窗口中运行命令（可以看到输出，支持交互）
local function RunInTerminal(cmd)
  -- 清掉底部的提示信息
  vim.cmd("redraw!")
  -- 关键：用 15new 创建一个全新的空白窗口，而不是复制当前代码窗口
  vim.cmd("botright 15new")
  -- 在这个新的空白窗口里开启终端
  vim.fn.termopen(cmd)
  -- 自动进入插入模式，方便立刻进行键盘输入（如 cin）
  vim.cmd("startinsert")
end

local fn = vim.fn

local function isdir(path)
  return fn.isdirectory(path) == 1
end

-- 查找项目根目录（向上找 CMakeLists.txt）
local function FindProjectRoot()
  local cmake_file = fn.findfile("CMakeLists.txt", ".;")
  if cmake_file == "" then
    return ""
  end
  return fn.fnamemodify(cmake_file, ":p:h")
end

-- 检测项目类型
local function DetectProjectMode()
  local project_root = FindProjectRoot()
  local current_dir = fn.expand("%:p:h")

  -- 如果找到 CMakeLists.txt，用它所在目录判断结构
  -- 否则用当前文件所在目录
  local check_dir = project_root ~= "" and project_root or current_dir
  local has_src_dir = isdir(check_dir .. "/src")
  local has_include_dir = isdir(check_dir .. "/include")
  local has_cmake = project_root ~= ""

  if has_cmake then
    if has_src_dir and has_include_dir then
      vim.notify("检测到: [CMake + 标准三层分离] 项目")
      return "cmake_standard"
    else
      vim.notify("检测到: [CMake + 单层混合] 项目")
      return "cmake_single"
    end
  else
    if has_src_dir and has_include_dir then
      vim.notify("检测到: [直接编译 + 标准三层分离] 项目")
      return "direct_standard"
    else
      vim.notify("检测到: [直接编译 + 单层混合] 项目")
      return "direct_single"
    end
  end
end

local function NinjaAvailable()
  fn.system("which ninja 2>/dev/null")
  return vim.v.shell_error == 0
end

-- ========== 直接编译：单文件 ==========
local function DirectCompileSingle(run)
  -- 先保存
  vim.cmd("write")

  local source = fn.expand("%:p")
  local base = fn.expand("%:p:r")
  local output = base .. ".out"

  vim.notify("直接编译（单层模式）...")

  -- 自动生成 compile_flags.txt 供 clangd 补全使用
  local cf_path = fn.expand("%:p:h") .. "/compile_flags.txt"
  local f = io.open(cf_path, "w")
  if f then
    f:write("-std=c++23\n-Wall\n-Wextra\n")
    f:close()
  end

  -- 编译（同步，拿错误信息）
  local compile_cmd = string.format(
    "g++-14 -std=c++23 -Wall -Wextra -g %s -o %s 2>&1",
    fn.shellescape(source),
    fn.shellescape(output)
  )
  local compile_out = fn.system(compile_cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("编译失败：\n" .. compile_out, vim.log.levels.ERROR)
    return
  end

  if run then
    RunInTerminal(fn.shellescape(output))
  else
    vim.notify("编译成功！输出文件: " .. output)
  end
end

-- ========== 直接编译：标准三层 ==========
local function DirectCompileStandard(run)
  vim.cmd("write")

  local current_dir = fn.expand("%:p:h")
  local source_dir = current_dir .. "/src"
  local include_dir = current_dir .. "/include"
  local build_dir = current_dir .. "/build"

  if not isdir(build_dir) then
    fn.mkdir(build_dir, "p")
  end

  local cpp_files = fn.glob(source_dir .. "/*.cpp", false, true)
  if #cpp_files == 0 then
    vim.notify("错误：在 src/ 目录下未找到任何 .cpp 文件！", vim.log.levels.ERROR)
    return
  end

  local main_file = fn.expand("%:t:r")
  local output_name = main_file .. ".out"
  local output_path = build_dir .. "/" .. output_name

  vim.notify("直接编译（标准三层模式）... 源文件: " .. #cpp_files .. " 个")

  -- 自动生成 compile_flags.txt 供 clangd 补全使用，包含头文件路径
  local cf_path = current_dir .. "/compile_flags.txt"
  local f = io.open(cf_path, "w")
  if f then
    f:write("-std=c++23\n-Wall\n-Wextra\n-I" .. include_dir .. "\n")
    f:close()
  end

  local sources = table.concat(vim.tbl_map(fn.shellescape, cpp_files), " ")
  local compile_cmd = string.format(
    "g++-14 -std=c++23 -Wall -Wextra -g -I%s %s -o %s 2>&1",
    fn.shellescape(include_dir),
    sources,
    fn.shellescape(output_path)
  )
  local compile_out = fn.system(compile_cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("编译失败：\n" .. compile_out, vim.log.levels.ERROR)
    return
  end

  if run then
    RunInTerminal("cd " .. fn.shellescape(build_dir) .. " && ./" .. output_name)
  else
    vim.notify("编译成功！输出文件: " .. output_path)
  end
end

-- ========== 查找可执行文件 ==========
local function FindExecutable(build_dir)
  -- 1. build_dir 下直接查找
  local direct_files = fn.glob(build_dir .. "/*", false, true)
  for _, file in ipairs(direct_files) do
    if fn.executable(file) == 1
        and not file:match("%.so$")
        and not file:match("%.a$")
        and not file:match("CMakeFiles") then
      return fn.fnamemodify(file, ":t")
    end
  end

  -- 2. build/bin
  local bin_dir = build_dir .. "/bin"
  if isdir(bin_dir) then
    local bin_files = fn.glob(bin_dir .. "/*", false, true)
    for _, file in ipairs(bin_files) do
      if fn.executable(file) == 1 and not file:match("%.so$") and not file:match("%.a$") then
        return "bin/" .. fn.fnamemodify(file, ":t")
      end
    end
  end

  -- 3. find 所有可执行文件
  local find_cmd = string.format(
    'find "%s" -maxdepth 3 -type f -executable ! -name "*.so" ! -name "*.a" ! -path "*/CMakeFiles/*" ! -name "cmake" ! -name "ctest" ! -name "cpack" 2>/dev/null',
    build_dir
  )
  local all = fn.systemlist(find_cmd)

  -- 过滤空行
  local filtered = {}
  for _, v in ipairs(all) do
    if v ~= "" then
      table.insert(filtered, v)
    end
  end

  if #filtered == 0 then
    return ""
  elseif #filtered == 1 then
    return filtered[1]:gsub("^" .. vim.pesc(build_dir) .. "/", "")
  else
    print("找到多个可执行文件:")
    for i, exe in ipairs(filtered) do
      local rel = exe:gsub("^" .. vim.pesc(build_dir) .. "/", "")
      print(string.format("%2d. %s", i, rel))
    end
    local choice = fn.input("请选择要运行的程序编号 (1-" .. #filtered .. "): ")
    local n = tonumber(choice)
    if n and n >= 1 and n <= #filtered then
      return filtered[n]:gsub("^" .. vim.pesc(build_dir) .. "/", "")
    else
      vim.notify("选择无效", vim.log.levels.WARN)
      return ""
    end
  end
end

-- ========== CMake 编译 ==========
local function CMakeCommon(run)
  vim.cmd("write")

  local project_root = FindProjectRoot()
  if project_root == "" then
    vim.notify("错误：未找到 CMakeLists.txt 文件！", vim.log.levels.ERROR)
    return
  end

  local build_dir = project_root .. "/build"
  if not isdir(build_dir) then
    fn.mkdir(build_dir, "p")
    vim.notify("创建 build 目录...")
  end

  local use_ninja = NinjaAvailable()

  -- 检查是否需要 CMake 配置
  local need_cmake = false
  local cache_path = build_dir .. "/CMakeCache.txt"
  local cc_json = build_dir .. "/compile_commands.json"

  -- 如果 CMakeCache 不存在，或者 compile_commands.json 没生成，都强制重新 CMake
  if fn.filereadable(cache_path) == 0 or fn.filereadable(cc_json) == 0 then
    need_cmake = true
  else
    local cache_lines = fn.readfile(cache_path)
    for _, line in ipairs(cache_lines) do
      if line:match("^CMAKE_HOME_DIRECTORY:INTERNAL=") then
        local old_path = line:match("=(.+)$")
        if old_path ~= project_root then
          vim.notify("检测到项目路径变更，强制重新配置 CMake...")
          need_cmake = true
        end
        break
      end
    end
  end

  -- CMake 配置（同步，需要拿错误信息）
  if need_cmake then
    vim.notify("运行 CMake 配置...")
    local cmake_cmd = "cd " .. fn.shellescape(build_dir) .. " && cmake"
        .. " -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
        .. " -DCMAKE_CXX_STANDARD=23"
        .. " -DCMAKE_C_COMPILER=gcc-14"
        .. " -DCMAKE_CXX_COMPILER=g++-14"
    if use_ninja then
      cmake_cmd = cmake_cmd .. " -G Ninja"
    end
    cmake_cmd = cmake_cmd .. " " .. fn.shellescape(project_root) .. " 2>&1"

    local cmake_out = fn.system(cmake_cmd)
    if vim.v.shell_error ~= 0 then
      vim.notify("CMake 配置失败：\n" .. cmake_out, vim.log.levels.ERROR)
      return
    end
    vim.notify("CMake 配置成功")
  end

  -- 编译（同步）
  vim.notify("编译中...")
  local nproc_out = fn.system("nproc 2>/dev/null")
  local jobs = math.min(4, tonumber(nproc_out:match("%d+")) or 4)
  local build_cmd
  if use_ninja then
    build_cmd = "cd " .. fn.shellescape(build_dir) .. " && ninja -j" .. jobs .. " 2>&1"
  else
    build_cmd = "cd " .. fn.shellescape(build_dir) .. " && make -j" .. jobs .. " 2>&1"
  end

  local build_out = fn.system(build_cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("编译失败：\n" .. build_out, vim.log.levels.ERROR)
    return
  else
    vim.notify("编译成功！")
  end

  -- 链接 compile_commands.json
  local cc_json = build_dir .. "/compile_commands.json"
  local target_json = project_root .. "/compile_commands.json"
  if fn.filereadable(cc_json) == 1 then
    -- 使用表结构传参，不经过 Shell 解析，绝不会因为路径字符出错
    fn.system({"rm", "-f", target_json})
    fn.system({"ln", "-sf", cc_json, target_json})
  end

  -- 运行（交互式，不会卡死）
  if run then
    local exe = FindExecutable(build_dir)
    if exe ~= "" then
      RunInTerminal("cd " .. fn.shellescape(build_dir) .. " && ./" .. exe)
    else
      vim.notify("警告：未找到可执行文件，请检查 CMakeLists.txt 中的 add_executable", vim.log.levels.WARN)
    end
  end
end

-- ========== 公共接口 ==========

function M.SmartCompileAndRun()
  local mode = DetectProjectMode()
  if mode == "cmake_standard" or mode == "cmake_single" then
    CMakeCommon(true)
  elseif mode == "direct_standard" then
    DirectCompileStandard(true)
  else
    DirectCompileSingle(true)
  end
end

function M.SmartCompileOnly()
  local mode = DetectProjectMode()
  if mode == "cmake_standard" or mode == "cmake_single" then
    CMakeCommon(false)
  elseif mode == "direct_standard" then
    DirectCompileStandard(false)
  else
    DirectCompileSingle(false)
  end
end

function M.CleanBuild()
  local mode = DetectProjectMode()
  if mode == "cmake_standard" or mode == "cmake_single" then
    vim.notify("清理 CMake 构建...")
    local project_root = FindProjectRoot()
    if project_root == "" then
      vim.notify("未找到项目根目录", vim.log.levels.ERROR)
      return
    end
    local build_dir = project_root .. "/build"
    if isdir(build_dir) then
      local choice = fn.confirm(
        "请选择清理方式:",
        "&完全删除build目录\n&使用ninja/make clean\n&取消",
        1
      )
      if choice == 1 then
        fn.system("rm -rf " .. fn.shellescape(build_dir))
        vim.notify("build 目录已删除")
      elseif choice == 2 then
        if fn.filereadable(build_dir .. "/build.ninja") == 1 then
          fn.system("cd " .. fn.shellescape(build_dir) .. " && ninja clean")
          vim.notify("ninja clean 完成")
        elseif fn.filereadable(build_dir .. "/Makefile") == 1 then
          fn.system("cd " .. fn.shellescape(build_dir) .. " && make clean")
          vim.notify("make clean 完成")
        else
          vim.notify("未找到构建文件", vim.log.levels.WARN)
        end
      end
    else
      vim.notify("build 目录不存在")
    end

  elseif mode == "direct_standard" then
    vim.notify("清理直接编译（标准模式）文件...")
    local build_dir = fn.expand("%:p:h") .. "/build"
    if isdir(build_dir) then
      local choice = fn.confirm("确定要删除 build 目录吗？", "&是\n&否", 2)
      if choice == 1 then
        fn.system("rm -rf " .. fn.shellescape(build_dir))
        vim.notify("build 目录已删除")
      end
    else
      vim.notify("build 目录不存在")
    end

  else
    vim.notify("清理直接编译（单层模式）文件...")
    local base = fn.expand("%:p:r")
    fn.system("rm -f " .. fn.shellescape(base .. ".o") .. " " .. fn.shellescape(base .. ".out") .. " 2>/dev/null")
    vim.notify("清理完成")
  end
end

function M.QuickClean()
  local mode = DetectProjectMode()
  if mode == "cmake_standard" or mode == "cmake_single" then
    local project_root = FindProjectRoot()
    if project_root == "" then
      vim.notify("未找到 CMakeLists.txt", vim.log.levels.ERROR)
      return
    end
    local build_dir = project_root .. "/build"
    if not isdir(build_dir) then
      vim.notify("build 目录不存在")
      return
    end
    if fn.filereadable(build_dir .. "/build.ninja") == 1 then
      vim.notify("使用 ninja clean 清理...")
      fn.system("cd " .. fn.shellescape(build_dir) .. " && ninja clean")
      vim.notify("清理完成")
    elseif fn.filereadable(build_dir .. "/Makefile") == 1 then
      vim.notify("使用 make clean 清理...")
      fn.system("cd " .. fn.shellescape(build_dir) .. " && make clean")
      vim.notify("清理完成")
    else
      vim.notify("未找到构建文件，无法清理", vim.log.levels.WARN)
    end
  else
    vim.notify("当前不是 CMake 项目模式")
  end
end

function M.DebugCMake()
  local project_root = FindProjectRoot()
  if project_root == "" then
    vim.notify("未找到 CMakeLists.txt", vim.log.levels.WARN)
    return
  end
  local build_dir = project_root .. "/build"
  print("=== 调试信息 ===")
  print("项目根目录: " .. project_root)
  print("构建目录: " .. build_dir)
  print("构建目录存在: " .. (isdir(build_dir) and "是" or "否"))

  if isdir(build_dir) then
    print("构建目录内容:")
    print(fn.system("ls -la " .. fn.shellescape(build_dir)))
    local exe = FindExecutable(build_dir)
    print("FindExecutable 返回: '" .. exe .. "'")
  end
end

-- 自动生成 compile_commands.json 和软链接（用于 LSP）
local function AutoGenerateCompileCommands()
  local project_root = FindProjectRoot()
  if project_root == "" then
    -- 如果不是 CMake 项目，检查是否是直接编译项目
    local current_dir = fn.expand("%:p:h")
    local has_src = isdir(current_dir .. "/src")
    local has_include = isdir(current_dir .. "/include")
    if has_src and has_include then
      -- 生成 compile_flags.txt
      local cf_path = current_dir .. "/compile_flags.txt"
      local f = io.open(cf_path, "w")
      if f then
        f:write("-std=c++23\n-Wall\n-Wextra\n-I" .. current_dir .. "/include\n")
        f:close()
      end
    end
    return
  end

  -- 对于 CMake 项目，检查并生成 compile_commands.json
  local build_dir = project_root .. "/build"
  local cc_json = build_dir .. "/compile_commands.json"
  local target_json = project_root .. "/compile_commands.json"

  -- 如果 build 目录不存在或 json 不存在，先配置 CMake
  if not isdir(build_dir) or fn.filereadable(cc_json) == 0 then
    fn.mkdir(build_dir, "p")
    local use_ninja = NinjaAvailable()
    local cmake_cmd = "cd " .. fn.shellescape(build_dir) .. " && cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_CXX_STANDARD=23 -DCMAKE_C_COMPILER=gcc-14 -DCMAKE_CXX_COMPILER=g++-14"
    if use_ninja then
      cmake_cmd = cmake_cmd .. " -G Ninja"
    end
    cmake_cmd = cmake_cmd .. " " .. fn.shellescape(project_root) .. " 2>&1"
    fn.system(cmake_cmd)
  end

  -- 创建软链接
  if fn.filereadable(cc_json) == 1 then
    fn.system({"rm", "-f", target_json})
    fn.system({"ln", "-sf", cc_json, target_json})
  end
end

-- 绑定到保存事件
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = { "CMakeLists.txt", "*.cpp", "*.hpp", "*.h" },
  callback = AutoGenerateCompileCommands,
})

-- 自动生成 .clang-tidy 配置文件
local function AutoGenerateClangTidy()
  local project_root = FindProjectRoot()
  if project_root == "" then return end  -- 只有在项目根目录才生成

  local clang_tidy_path = project_root .. "/.clang-tidy"
  if fn.filereadable(clang_tidy_path) == 1 then return end  -- 如果已存在，不覆盖

  -- 生成默认 .clang-tidy 配置（适合 C++23 开发）
  local config = [[
Checks: >
  *,
  -clang-analyzer-alpha*,
  -llvm-include-order,
  -modernize-use-trailing-return-type,
  clang-diagnostic-*,
  readability-*,
  performance-*,
  bugprone-*,
  cppcoreguidelines-*,
  modernize-*,
  -modernize-use-auto,
  -readability-else-after-return,
  -readability-identifier-length,
  -readability-magic-numbers

WarningsAsErrors: ''
HeaderFilterRegex: '.*'
AnalyzeTemporaryDtors: false
FormatStyle: file
CheckOptions:
  - key: readability-identifier-naming.ClassCase
    value: CamelCase
  - key: readability-identifier-naming.VariableCase
    value: camelBack
  - key: readability-identifier-naming.FunctionCase
    value: camelBack
  - key: readability-identifier-naming.MemberCase
    value: camelBack
  - key: readability-identifier-naming.NamespaceCase
    value: CamelCase
]]

  local file = io.open(clang_tidy_path, "w")
  if file then
    file:write(config)
    file:close()
    vim.notify(".clang-tidy 已自动生成", vim.log.levels.INFO)
  else
    vim.notify("无法生成 .clang-tidy 文件", vim.log.levels.ERROR)
  end
end

-- 绑定到保存事件（仅 C++ 文件）
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = { "*.cpp", "*.hpp", "*.h", "CMakeLists.txt" },
  callback = AutoGenerateClangTidy,
})

return M
