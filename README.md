# dotfiles

我的个人配置仓库：**Neovim（基于 [LazyVim](https://github.com/LazyVim/LazyVim)）写代码；Emacs 写中文文档，也接 Rust / Zig 的开发**（`rust-ts-mode` + `eglot`、`zig-ts-mode` + `zls`）。

两套配置都通过**软链接**（Windows 上是目录联接 junction）挂到各自的配置目录，所以仓库里的改动会立刻生效，多台设备之间用 git 同步。

## 目录结构

```
dotfiles/
├── install.ps1          # Windows 安装脚本（PowerShell）
├── install.sh           # Linux / macOS / WSL / Git Bash 安装脚本
├── LICENSE
├── tests/
│   └── install-idempotency.ps1   # 安装脚本的幂等性回归测试
├── nvim/                # 真正的 nvim 配置，会被链接到 %LOCALAPPDATA%\nvim
│   ├── init.lua
│   ├── lazy-lock.json   # 插件版本锁定，跟着仓库走
│   ├── lazyvim.json     # 已启用的 LazyVim extras
│   ├── .neoconf.json
│   ├── stylua.toml
│   └── lua/
│       ├── config/      # options / keymaps / autocmds / lazy
│       └── plugins/     # 自定义插件与主题
└── emacs/               # 真正的 Emacs 配置，会被链接到 ~/.emacs.d
    ├── early-init.el    # 帧创建前：关 chrome、定字体
    ├── init.el          # 入口，只做装配
    ├── lisp/            # packages / ui / completion / markdown / rust / zig
    └── themes/          # 自己写的 rose-pine（main / moon / dawn）
```

## 安装

脚本会自己找配置目录，**不写死任何用户路径**：

| 系统 | nvim 配置目录 | emacs 配置目录 |
| --- | --- | --- |
| Windows | `%LOCALAPPDATA%\nvim` | `%APPDATA%\.emacs.d` **和** `~/.emacs.d`（两个都链） |
| Linux / macOS | `$XDG_CONFIG_HOME/nvim`（默认 `~/.config/nvim`） | `~/.emacs.d` |

### Windows 上为什么链两个位置

Emacs 在 Windows 上按**启动时的环境**决定去哪找配置：

- 环境里有 `HOME` → 用 `$HOME\.emacs.d`（从 Git Bash 一类终端启动时会继承）
- 没有 `HOME` → Emacs 自己把 `HOME` 设成 `%APPDATA%`，即 `%APPDATA%\.emacs.d`（从开始菜单 / 资源管理器启动）

`HOME` 不是 Windows 默认环境变量，所以同一个 Emacs 换个方式启动就可能读另一个目录。安装脚本不猜，**两处都链到同一个仓库**，怎么启动都对。

Linux / macOS 上 `HOME` 一定存在，只链 `~/.emacs.d`。这里不用 `~/.config/emacs`：Emacs 的判定是「`~/.emacs.d` 存在就用它，否则 `$XDG_CONFIG_HOME/emacs`，都没有再回落到 `~/.emacs.d`」，统一用前者三平台一致。

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

Emacs 不自动联网：启动只读本地缓存，装依赖是显式动作。装完之后在 Emacs 里跑一次 `M-x my/bootstrap-packages`（或命令行 `emacs --batch -l ~/.emacs.d/init.el --eval "(my/bootstrap-packages)"`），再重启。某个源不通会自动换镜像，官方源优先。详见 [emacs/README.md](emacs/README.md)。

> `install.sh` 只面向 Linux / macOS / WSL（POSIX 环境）。Windows 请用 `install.ps1`，两者逻辑一致，只是链接方式不同。

### 先看看会做什么

```powershell
.\install.ps1 -DryRun        # PowerShell
./install.sh --dry-run       # bash
```

其他参数：

| PowerShell | bash | 作用 |
| --- | --- | --- |
| `-NoPlugins` | `--no-plugins` | 只建立链接，不装 nvim 插件 |
| `-Update` | `--update` | 先 `git pull --ff-only` 再链接（第二台机器用） |
| `-Target DIR` | `--target DIR` | 指定 nvim 配置目录（测试用） |
| `-EmacsTarget DIR` | `--emacs-target DIR` | 指定 emacs 配置目录（测试用） |

### 验证脚本的幂等性

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\install-idempotency.ps1
```

在 `<repo>\.install-test` 里跑 6 个场景、27 项检查，全程用 `-Target` / `-EmacsTarget` 指向临时目录，**不碰真实配置**：

| 场景 | 期望 |
| --- | --- |
| 全新安装，连跑两次 | 第二次只打印 already links，不产生任何备份 |
| 目标已是真实目录 | 备份一次、内容完好；再跑不多出备份 |
| 目标是指向别处的链接 | 直接改指仓库；链接不备份；原目标目录不被删 |
| 目标是坏链接 | 自动修复；再跑无动作 |
| dry-run | 不建链接、不备份、不改真实目录 |
| 同一秒内连跑两次 | 备份名不撞车 |

> `install.ps1` **必须保持纯 ASCII**。Windows PowerShell 5.1 对没有 BOM 的脚本按 ANSI 代码页解码，中文可能吃掉收尾引号导致解析失败；加 UTF-8 BOM 也能解决，但任何重写文件的工具都可能把它丢掉，所以纯 ASCII 才是能长期维持的答案。`install.sh` 由 bash 解析，无此限制。

## Emacs 配置

主力是中文 Markdown；Rust / Zig 则吃 Emacs 30 的内置能力——`rust-ts-mode` + `eglot`、
`zig-ts-mode` + `zls`，没有 evil，也没有 git 客户端。

- 主题是自己按[官方色板](https://rosepinetheme.com/palette/)写的 `rose-pine`，三个变体，`C-c t` 切换
- 补全用 vertico + orderless + marginalia + consult
- 字体：`JetBrainsMono NF`（等宽 + Nerd 图标）+ `Noto Serif SC`（中文正文）
- Markdown：软换行、比例字体、居中窄栏、CJK 表格对齐
- Rust / Zig：tree-sitter 高亮 + eglot（rust-analyzer / zls）+ 保存时 rustfmt / zig fmt
- 语法库要单独编译：装好依赖后跑一次 `M-x my/install-treesit-grammars`

细节、键位速查和排错见 [emacs/README.md](emacs/README.md)。

## 安全说明

- 原来的配置**不会丢**：会被重命名为 `nvim.bak-<时间戳>` / `emacs.bak-<时间戳>`。
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

nvim 插件本体装在 Neovim 的 data 目录里（Windows：`%LOCALAPPDATA%\nvim-data`），**不进仓库**。仓库里只跟 `lazy-lock.json`，保证各设备版本一致。

Emacs 的包由 `package.el` 管，装在 `~/.emacs.d/elpa/`（已被 `emacs/.gitignore` 排除），**同样不进仓库**。换机器时第一次启动会按 `init.el` 里的声明重新下载。

### 锁文件为什么会挡住 pull

`nvim/` 本身就是 git 工作树，而 lazy.nvim 会**就地重写** `nvim/lazy-lock.json`。只要本机装上的插件版本和仓库里锁定的不完全一致（`:Lazy update`、插件新增/移除、某台机器上首次安装），工作树就脏了，`git pull --ff-only` 会直接拒绝——这就是「拉不下来」的原因。

规则很简单：**以仓库里的 lock 为准**。

- `install.sh --update` / `install.ps1 -Update` 会在 pull 之前把这台机器的 lock 漂移丢掉，所以不会再被卡住；
- 要升级插件，在**一台**机器上 `:Lazy update` → `git add nvim/lazy-lock.json` → commit/push，另一台再 `--update` 即可（自动 `Lazy restore` 会对齐）；
- 想临时看本机装了什么，用 `:Lazy` 面板或 `git -C <repo> status`，别指望 lock 长期保持「本机最新」。

## 回滚

```powershell
# PowerShell
Remove-Item "$env:LOCALAPPDATA\nvim"          # 只删链接，不动仓库
Move-Item "$env:LOCALAPPDATA\nvim.bak-20250101-120000" "$env:LOCALAPPDATA\nvim"
Remove-Item "$HOME\.emacs.d"
Move-Item "$HOME\.emacs.d.bak-20250101-120000" "$HOME\.emacs.d"
```

```bash
# bash
rm ~/.config/nvim
mv ~/.config/nvim.bak-20250101-120000 ~/.config/nvim
rm ~/.emacs.d
mv ~/.emacs.d.bak-20250101-120000 ~/.emacs.d
```

## 以后加别的配置

在仓库根目录新建同级目录（比如 `wezterm/`、`git/`），在脚本里多加一次 `link_config`（bash）或 `Install-Link`（PowerShell）调用即可。

## 依赖

- **git**
- **Neovim 0.11+**（LazyVim 的要求）
- **Emacs 29+**（配置用到 `keymap-set`；实际开发验证于 30.1）
- Windows 自带 PowerShell 5.1 即可
- 建议装 `ripgrep`、`fd`，LazyVim 的搜索会用到
- 可选：[pandoc](https://pandoc.org/)（`winget install JohnMacFarlane.Pandoc`），Markdown 预览/导出要用

## License

Apache-2.0，见 [LICENSE](LICENSE)。
