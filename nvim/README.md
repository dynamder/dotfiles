# nvim

这是实际使用的 Neovim 配置，由仓库根目录的 `install.sh` / `install.ps1`
链接到 Neovim 的配置目录。安装与同步说明见 [仓库 README](../README.md)。

- `lua/config/` — 选项、快捷键、自动命令、lazy.nvim 启动配置
- `lua/plugins/` — 插件与主题（`colorscheme.lua` 是实际生效的配置，`example.lua` 是模板，不加载）
- `lazy-lock.json` — 插件版本锁定，请随提交一起更新
- `lazyvim.json` — 已启用的 LazyVim extras
