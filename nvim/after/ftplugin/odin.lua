-- Odin: 官方风格用真正的 tab，一个 tab 宽 4 列。
-- odinfmt(x) 格式化输出也是 tab，所以这里跟着用 noexpandtab，避免
-- 「手打空格 -> 保存被改成 tab -> 再打又是空格」来回抖动。
vim.bo.expandtab = false
vim.bo.tabstop = 4
vim.bo.softtabstop = 4
vim.bo.shiftwidth = 4
