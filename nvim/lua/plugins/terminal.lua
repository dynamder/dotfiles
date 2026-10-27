-- 双平台只维护一份配置：交互式终端的 shell 在运行时按「平台 + 是否装了」探测。
--   Windows : nu(nushell) -> pwsh
--   Linux   : fish -> zsh -> bash
-- 都探测不到就不设，Snacks 会退回 vim.o.shell。
--
-- 注意这里只影响 :terminal / <leader>ft / <leader>fT / <c-/>，
-- 不影响 :! 和 system()（那两个仍然用 &shell，保持各平台默认最安全）。

local function pick(names)
  for _, name in ipairs(names) do
    if vim.fn.executable(name) == 1 then
      return name
    end
  end
end

local terminal_shell = pick(vim.fn.has("win32") == 1 and { "nu", "pwsh" } or { "fish", "zsh", "bash" })

return {
  {
    "folke/snacks.nvim",
    opts = {
      terminal = { shell = terminal_shell },
    },
  },
}
