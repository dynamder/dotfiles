# dotfiles

我的个人配置仓库，目前是 Neovim（基于 [LazyVim](https://github.com/LazyVim/LazyVim)）。

配置通过**软链接**（Windows 上是目录联接 junction）挂到 Neovim 的配置目录，所以仓库里的改动会立刻生效，多台设备之间用 git 同步。

## 目录结构

```
dotfiles/
├── install.ps1          # Windows 安装脚本（PowerShell）
├── install.sh           # Linux / macOS / WSL / Git Bash 安装脚本
├── LICENSE
└── nvim/                # 真正的 nvim 配置，会被链接到配置目录
    ├── init.lua
    ├── lazy-lock.json   # 插件版本锁定，跟着仓库走
    ├── lazyvim.json     # 已启用的 LazyVim extras
    ├── .neoconf.json
    ├── stylua.toml
    └── lua/
        ├── config/      # options / keymaps / autocmds / lazy
        └── plugins/     # 自定义插件与主题
```

## 安装

脚本会自己找配置目录，**不写死任何用户路径**：

| 系统 | 配置目录 |
| --- | --- |
| Windows | `%LOCALAPPDATA%\nvim` |
| Linux / macOS | `$XDG_CONFIG_HOME/nvim`（默认 `~/.config/nvim`） |

### Windows（PowerShell）

```powershell
git clone https://github.com/dynamder/dotfiles.git "$HOME\dotfiles"
cd "$HOME\dotfiles"
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### Linux / macOS / WSL

```bash
git clone https://github.com/dynamder/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

首次进入 nvim 会下载 LazyVim 和插件，等它跑完即可。

> `install.sh` 只面向 Linux / macOS / WSL（POSIX 环境）。Windows 请用 `install.ps1`，两者逻辑一致，只是链接方式不同。

### 先看看会做什么

```powershell
.\install.ps1 -DryRun        # PowerShell
./install.sh --dry-run       # bash
```

其他参数：

| PowerShell | bash | 作用 |
| --- | --- | --- |
| `-NoPlugins` | `--no-plugins` | 只建立链接，不装插件 |
| `-Update` | `--update` | 先 `git pull --ff-only` 再链接（第二台机器用） |
| `-Target DIR` | `--target DIR` | 指定配置目录（测试用） |

## 安全说明

- 原来的配置**不会丢**：会被重命名为 `nvim.bak-<时间戳>`。
- Windows 用的是目录联接（junction），不需要开启开发者模式或管理员权限。
- 重复运行是幂等的：已经链接正确时会跳过。

## 多设备同步

改完配置在仓库里提交推送，另一台机器拉取：

```bash
cd ~/dotfiles
git pull --ff-only
nvim --headless "+Lazy! restore" +qa   # 按 lazy-lock.json 对齐插件版本
```

也可以一条命令：`./install.sh --update`（PowerShell 用 `.\install.ps1 -Update`）。

插件本体装在 Neovim 的 data 目录里（Windows：`%LOCALAPPDATA%\nvim-data`），**不进仓库**。仓库里只跟 `lazy-lock.json`，保证各设备版本一致。

### 锁文件为什么会挡住 pull

`nvim/` 本身就是 git 工作树，而 lazy.nvim 会**就地重写** `nvim/lazy-lock.json`。只要本机装上的插件版本和仓库里锁定的不完全一致（`:Lazy update`、插件新增/移除、某台机器上首次安装），工作树就脏了，`git pull --ff-only` 会直接拒绝——这就是「拉不下来」的原因。

规则很简单：**以仓库里的 lock 为准**。

- `install.sh --update` / `install.ps1 -Update` 会在 pull 之前把这台机器的 lock 漂移丢掉，所以不会再被卡住；
- 要升级插件，在**一台**机器上 `:Lazy update` → `git add nvim/lazy-lock.json` → commit/push，另一台再 `--update` 即可（自动 `Lazy restore` 会对齐）；
- 想临时看本机装了什么，用 `:Lazy` 面板或 `git -C <repo> status`，别指望 lock 长期保持「本机最新」。

## 回滚

```bash
# bash
rm ~/.config/nvim
mv ~/.config/nvim.bak-20250101-120000 ~/.config/nvim
```

```powershell
# PowerShell
Remove-Item "$env:LOCALAPPDATA\nvim"          # 只删链接，不动仓库
Move-Item "$env:LOCALAPPDATA\nvim.bak-20250101-120000" "$env:LOCALAPPDATA\nvim"
```

## 以后加别的配置

在仓库根目录新建同级目录（比如 `wezterm/`、`git/`），照 `nvim/` 的方式在脚本里加一段即可。目前脚本只处理 `nvim/`。

## 依赖

- **git**
- **Neovim 0.11+**（LazyVim 的要求）
- Windows 自带 PowerShell 5.1 即可
- 建议装 `ripgrep`、`fd`，LazyVim 的搜索会用到

## License

Apache-2.0，见 [LICENSE](LICENSE)。
