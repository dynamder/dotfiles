-- rust-analyzer resilience for rustup-shim installs.
--
-- ~/.cargo/bin/rust-analyzer (Windows: rust-analyzer.exe) is not the real
-- binary -- it is a symlink to rustup. On startup it resolves the toolchain
-- for the project directory and then execs
--   ~/.rustup/toolchains/<toolchain>/bin/rust-analyzer[.exe]
-- If that toolchain has no `rust-analyzer` component installed, rustup prints
--   error: Unknown binary 'rust-analyzer.exe' in official toolchain '<tc>'
-- and exits with code 1, which Neovim surfaces only as a terse
--   "rust_analyzer client quit, exit code 1"
--
-- The shim stays the default whenever it can work, because its version always
-- matches the project's toolchain. Only when the resolved toolchain is missing
-- the component do we fall back to another toolchain's real binary, and we say
-- so out loud instead of failing silently.
--
-- Note: `server.cmd` must always return a table. rustaceanvim's `auto_attach`
-- indexes the evaluated result (`cmd[1]`), so returning nil raises inside the
-- FileType handler and the client never starts at all.

local uv = vim.uv or vim.loop

local function exe(name)
  return vim.fn.has("win32") == 1 and (name .. ".exe") or name
end

local function rustup_home()
  local home = vim.env.RUSTUP_HOME
  if home and home ~= "" then
    return home
  end
  return vim.fs.joinpath(vim.fn.expand("~"), ".rustup")
end

---@param toolchain string
---@return string|nil real rust-analyzer binary shipped by `toolchain`
local function toolchain_bin(toolchain)
  local path = vim.fs.joinpath(rustup_home(), "toolchains", toolchain, "bin", exe("rust-analyzer"))
  return uv.fs_stat(path) and path or nil
end

---@return string[] toolchains that actually ship rust-analyzer, stable first
local function toolchains_with_ra()
  local found = {}
  local handle = uv.fs_scandir(vim.fs.joinpath(rustup_home(), "toolchains"))
  while handle do
    local name = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if toolchain_bin(name) then
      found[#found + 1] = name
    end
  end
  table.sort(found, function(a, b)
    local a_stable = a:match("^stable") ~= nil
    local b_stable = b:match("^stable") ~= nil
    if a_stable ~= b_stable then
      return a_stable
    end
    return a < b
  end)
  return found
end

---@param dir string
---@return string nearest Rust project root
local function project_root(dir)
  local hit = vim.fs.find({ "Cargo.toml", "rust-toolchain.toml", "rust-toolchain" }, {
    upward = true,
    path = dir,
    type = "file",
  })[1]
  return hit and vim.fs.dirname(hit) or dir
end

---The toolchain rustup would pick for `dir`: exactly what the shim resolves.
---@param dir string
---@return string|nil
local function active_toolchain(dir)
  local ok, res = pcall(function()
    return vim.system({ exe("rustup"), "show", "active-toolchain" }, { cwd = dir, text = true }):wait(5000)
  end)
  if not ok or not res or res.code ~= 0 then
    return nil
  end
  return (res.stdout or ""):match("^(%S+)")
end

local function exepath_or_binary(binary)
  local path = vim.fn.exepath(binary)
  return #path > 0 and path or binary
end

local function current_root()
  local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  if dir == "" or dir == "." then
    dir = vim.fn.getcwd()
  end
  return project_root(dir)
end

local cache = {}

---@param root string
---@return { bin: string, missing?: string, fallback?: string }
local function lookup(root)
  if cache[root] then
    return cache[root]
  end

  local toolchain = active_toolchain(root)
  local entry
  if not toolchain or toolchain_bin(toolchain) then
    -- Shim works, or we cannot tell: fail open and keep the version-matched shim.
    entry = { bin = exepath_or_binary("rust-analyzer") }
  else
    local fallback = toolchains_with_ra()[1]
    local bin = fallback and toolchain_bin(fallback)
    entry = {
      bin = bin or exepath_or_binary("rust-analyzer"),
      missing = toolchain,
      fallback = bin and fallback or nil,
    }
  end

  cache[root] = entry
  return entry
end

---rustaceanvim's own logfile, once it has been set up. Only available after
---`setup()`, hence the lazy lookup; nil means "do not pass --log-file at all"
---rather than passing a guess.
---@return string|nil
local function ra_logfile()
  local ok, logfile = pcall(function()
    return require("rustaceanvim.config").server.logfile
  end)
  if ok and type(logfile) == "string" and logfile ~= "" then
    return logfile
  end
  local generated = vim.fn.tempname()
  return generated ~= "" and (generated .. "-rust-analyzer.log") or nil
end

---@return string[]
local function rust_analyzer_cmd()
  local bin = lookup(current_root()).bin
  local logfile = ra_logfile()
  if not logfile then
    return { bin }
  end
  return { bin, "--log-file", logfile }
end

local warned = {}

return {
  {
    "mrcjkb/rustaceanvim",
    ft = { "rust" },
    init = function()
      -- Surface the missing component on open, so it is never a bare exit code again.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "rust",
        callback = function()
          local root = current_root()
          local entry = lookup(root)
          if not entry.missing or warned[root] then
            return
          end
          warned[root] = true
          if entry.fallback then
            vim.notify(
              string.format(
                "Toolchain %s ships no rust-analyzer component; using %s instead.\n"
                  .. "Permanent fix: rustup component add rust-analyzer --toolchain %s",
                entry.missing,
                entry.fallback,
                entry.missing
              ),
              vim.log.levels.WARN,
              { title = "rust-analyzer" }
            )
          else
            vim.notify(
              string.format(
                "Toolchain %s ships no rust-analyzer component and no fallback exists, so the LSP will exit.\n"
                  .. "Fix: rustup component add rust-analyzer --toolchain %s",
                entry.missing,
                entry.missing
              ),
              vim.log.levels.ERROR,
              { title = "rust-analyzer" }
            )
          end
        end,
      })
    end,
    opts = function(_, opts)
      opts.server = opts.server or {}
      opts.server.cmd = rust_analyzer_cmd
      return opts
    end,
  },
}
