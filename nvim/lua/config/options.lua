-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- 不要在这里写死 &shell：Windows 上有 nu、Linux 上是 fish，写死任何一个都会在
-- 另一台机器上翻车；而且 Windows 的 &shellcmdflag 默认是 "/s /c"，塞进 nushell
-- 之后 `:!` 和 `system()` 实际上是坏的。
-- 交互式终端（<leader>ft / <c-/>）用哪个 shell，见 lua/plugins/terminal.lua。

