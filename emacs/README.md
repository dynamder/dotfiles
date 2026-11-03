# Emacs 配置

现在管三件事：**中文 Markdown 写得舒服**，**Rust / Zig 能直接写**
（`rust-ts-mode` + `eglot`、`zig-ts-mode` + `zls` 各一套，没有 evil），
**顺手调出 lazygit**——不装 magit，git 界面直接用你已经在用的那个 TUI。

## 结构

```
emacs/                     ← 这就是 ~/.emacs.d
├── early-init.el          帧创建前：关 chrome、定字体，避免启动闪一下
├── init.el                入口，只做装配，逐个 require lisp/ 下的模块
├── lisp/
│   ├── my-packages.el     包源（GNU + NonGNU + MELPA）、use-package 设置
│   ├── my-ui.el           字体、主题、doom-modeline、窗口与交互
│   ├── my-completion.el   vertico / orderless / marginalia / consult
│   │                      + corfu / cape（buffer 内补全）、embark、which-key
│   ├── my-markdown.el     写作环境：软换行、比例字体、居中栏、表格对齐
│   ├── my-git.el          git：在项目根目录起一个 lazygit 终端（C-c g）
│   ├── my-treesit.el      tree-sitter 语法库：源地址、编译器、一键安装
│   ├── my-rust.el         Rust：rust-ts-mode + eglot + rustfmt
│   └── my-zig.el          Zig：zig-ts-mode + zls + zig fmt
├── bin/
│   ├── cc.bat             把 zig cc 包装成 treesit 能用的 cc
│   └── c++.bat            同上，C++ 版（只有带 scanner.cc 的语法库才用）
└── themes/
    ├── rose-pine-common.el      三个变体共用的调色板 + 脸面表
    ├── rose-pine-theme.el       主变体（深色）
    ├── rose-pine-moon-theme.el  偏紫的深色
    └── rose-pine-dawn-theme.el  浅色
```

改哪一块，光标放表达式末尾 `C-x C-e` 就地求值即可，不用重启。

## 首次启动

1. 跑安装脚本（把 `~/.emacs.d` 链接到这个目录），或者手动：
   ```powershell
   # 两个位置都链（Windows 上 Emacs 按启动环境决定读哪个，见根 README）
   New-Item -ItemType Junction -Path "$env:APPDATA\.emacs.d" -Target "D:\dotfiles\emacs"
   New-Item -ItemType Junction -Path "$HOME\.emacs.d"        -Target "D:\dotfiles\emacs"
   ```
2. 装依赖：`M-x my/bootstrap-packages`（需要网络，会显示每个包的进度）。
   也可以不开 Emacs，直接在命令行跑：
   ```powershell
   emacs --batch -l "$HOME\.emacs.d\init.el" --eval "(my/bootstrap-packages)"
   ```
   装完会提示结果；有装不上的包会列出来，重跑即可。
3. **重启 Emacs**。装包只在内存里生效，重启后才全部加载。
4. 装 **tree-sitter 语法库**。Rust / Zig / Markdown 的高亮全靠它，而官方
   Windows 构建只带 `libtree-sitter.dll` 本体，语法库得自己编：

   ```elisp
   M-x my/install-treesit-grammars      ; C-u 强制重装
   ```

   一条命令装 rust / zig / markdown / markdown_inline。源地址写在
   `lisp/my-treesit.el` 的 `my/treesit-grammars` 里（Emacs 30 的
   `treesit-language-source-alist` 默认是空的，不填就得每次手输网址）。

   编译器用仓库自带的 `bin/cc.bat`，它把参数转发给 `zig cc`，所以**不要求
   PATH 上有 cc、也不用装 mingw**，只要 Zig 本身在 PATH 上。路径由
   `user-emacs-directory` 算出来，换机器 clone 完就能用，不需要复制任何文件。

   > **`zig cc` 不能原样当 `cc` 用。** 它在 Windows 上把对象文件叫 `parser.obj`，
   > 而 treesit 的链接步只收集 `*.o`，于是链接命令的输入列表是空的，报
   > `zig: error: no input files`。所以 `cc.bat` 在 `-c` 编译成功后要把
   > `<源文件名>.obj` 改名成 `.o`。

   macOS / Linux 不需要这套：`my/treesit-cc-program` 为 nil，直接走系统 `cc`。
   验证：`M-: (treesit-language-available-p 'rust)` 返回 `t`。

5. 预览/导出需要 **pandoc**：
   ```powershell
   winget install JohnMacFarlane.Pandoc
   ```

> 为什么不是「启动时自动装」：`use-package` 的 `:ensure` 在包缺失时会主动调用
> `package-refresh-contents`，等于把同步网络请求塞进启动路径。一旦某个源被丢包，
> Emacs 会停在 `Contacting host: elpa.gnu.org:443`，而且卡在 C 层连接调用里，
> `C-g` 也按不动。所以装包改成显式动作，启动路径上不发起任何网络请求。
> 启动耗时见下面的「启动速度」。

### 源不通会自动换

每个归档有多个候选地址，**官方排第一，镜像只作为备胎**：

```elisp
gnu    → elpa.gnu.org  → ustc → tuna
nongnu → elpa.nongnu.org → ustc → tuna
melpa  → melpa.org     → ustc → tuna
```

它不会只按顺序硬试，分两步走，**两步都在子进程里**：

1. **探测**（8 秒上限）：取每个地址的 `archive-contents.sig`（几百字节），
   要求 HTTP 200。
2. **下载**（60 秒上限）：子进程里跑 `package-refresh-contents`，
   判断成功不看退出码，而是看 `archives/<name>/archive-contents` 是否真的落盘。

| 探测结果 | 处理 |
| --- | --- |
| `ok` | 下载 |
| `fail`（快速失败：DNS 不存在 / 连接被拒 / 403 / 502） | 先挪后，最后再试一次——探测可能不准 |
| `timeout`（卡住，被 kill） | **直接跳过，永不重试** |

第三档是关键：`timeout` 意味着连接会无限期挂住，而 Emacs 一旦卡进 C 层，
连 `C-g` 都按不动。所以这种地址一次都不碰。

> **为什么连下载也要放进子进程**：实测（Windows + 本地代理）`url-retrieve`
> 会**在返回之前**就卡死，异步回调都进不去，`accept-process-output` 的截止
> 时间根本没机会跑，进程内的任何超时都无效。父进程唯一能做的就是在外面
> 到点 `kill`。子进程用 `kill-emacs` 返回码也不可靠（实测回来是 0），
> 所以结论通过临时文件回传。

选中的地址写回 `package-archives`，后面的 `package-install` 也从它下载。
所以正常网络下完全走官方，不会碰镜像。

### Windows 上必须配 CA 证书

`gnutls-trustfiles` 在 Windows 上默认是一串 `/etc/ssl/...` 的 Unix 路径，
**一个都不存在**。后果是所有 HTTPS 握手都以 `connection-failed "deleted"`
结束，`M-x my/diagnose-network` 会显示满屏 0.2 秒的 `fail`——看起来像网络
被封，其实是证书库没配上。

`my/ensure-ca-bundle` 会在启动时检查：如果默认路径全都不存在，就换成本机
真实存在的那个（优先 Git for Windows 自带的 `ca-bundle.crt`）。子进程也会
带上同一份设置，否则它用 `-Q` 启动、读不到这个变量，会退回失败的默认值。

### 代理默认关闭

```elisp
(setq my/use-proxy nil)        ; 默认值
(setq my/proxy-override "127.0.0.1:7897")   ; 需要时手动指定
```

实测这台机器上 Emacs 走本地代理（`127.0.0.1:7897`）会拿到 **HTTP 400**
——代理不接受 Emacs 发的请求；而直连配合正确的 CA 是 **200**。
所以默认直连。要开代理就 `(setq my/use-proxy t)`，端口从注册表动态读
（`ProxyEnable` / `ProxyServer`，代理换端口会自动跟上）；走代理全挂时
`my/bootstrap-packages` 会自动退回直连再试一轮。

想看当前每个归档用了哪个地址：`M-x my/packages-status`。
想看每个候选地址的探测结果和耗时：`M-x my/diagnose-network`。
想固定用官方、彻底禁掉镜像：把 `my-packages.el` 里 `my/archive-sources`
每一项后面的两行删掉即可。探测本身也是开关：`my/probe-before-download`。

### 只装缺的包，不重复下载索引

`M-x my/bootstrap-packages` 发现本地已有索引时**不会再刷新**（索引在
`elpa/archives/` 里，几 MB，每次重下没必要），直接装缺的包：

```
Using cached index (6772 packages). C-u to force a refresh.
```

要强制重下索引就用 `C-u M-x my/bootstrap-packages`。
上次每个归档实际可用的地址会写进 `my-archive-cache.el`（已在 gitignore 里），
下次先试它——所以「官方不通、每次都要等一个探测超时」只发生在第一次。

## 跨平台

同一份配置在 Windows 和 Linux（CachyOS / Arch 系）上跑。平台差异只有下面几处，
其余代码里没有 `system-type` 判断。

### 系统依赖

Arch 系一条命令：

```bash
sudo pacman -S --needed git base-devel rust rustfmt rust-analyzer zls lazygit \
    ttf-jetbrains-mono-nerd noto-fonts-cjk
```

| 用途 | 包 | 说明 |
| --- | --- | --- |
| 编译语法库 | `base-devel`（gcc） | treesit 直接调 `cc`，Linux 不需要包装脚本 |
| Rust 补全 | `rust-analyzer` | 用 rustup 的话：`rustup component add rust-analyzer rustfmt` |
| Zig 补全 | `zls` | 大版本要跟 zig 对得上 |
| git 界面 | `lazygit` | `C-c g` 调出；不在 PATH 上会明确报错，不会静默失败 |
| 字体 | `ttf-jetbrains-mono-nerd`、`noto-fonts-cjk` | 名字见「字体」一节 |

装完用 `M-: (treesit-available-p)` 确认这个 Emacs 编进了 tree-sitter
（Arch 官方包默认启用）。返回 `nil` 就先换包，否则后面全都白搭。

### 和 Windows 的差异

| 项 | Windows | Linux / macOS |
| --- | --- | --- |
| 语法库编译器 | `bin/cc.bat` 包装 `zig cc` | 直接调系统 `cc`；`my/treesit-cc-program` 为 nil |
| 装语法库 | `M-x my/install-treesit-grammars` | 同左，一条命令 |
| 字体名 | `JetBrainsMono NF` / `Noto Serif SC` | `JetBrainsMono Nerd Font` / `Noto Serif CJK SC`，自动挑 |
| CA 证书 | 探测 Git for Windows 的 bundle | 系统 `/etc/ssl/certs` 直接可用，那段逻辑不触发 |
| 代理 | 读注册表 | `my/use-proxy` 默认 nil，不涉及 |

`bin/*.bat` 在 Linux 上不参与任何流程。`.gitattributes` 固定它们的 CRLF，
只是为了让 Windows 上 checkout 回来还能跑。

## 启动速度

量的是 batch 模式（`emacs --batch -l init.el --eval '(kill-emacs)'`）。它不含
GUI 的建帧、字体落地和主题渲染，所以**真实 GUI 启动会比这组数更大**。要看真实
数字就在你自己的会话里跑 `M-x my/startup-report`，它把耗时拆成
before-init / 各模块 / after 三段。

| | 空 Emacs 基线 | 加载完整配置 | 配置本身 |
| --- | --- | --- | --- |
| 优化前 | 0.174s | 0.70s | ≈ 0.53s |
| 优化后 | 0.174s | 0.60s | ≈ 0.43s |

优化后各模块（`my/load-times`）：

```
my-packages   0.081s
my-ui         0.072s
my-completion 0.057s
my-treesit    0.009s
其余四个      各 0.002s
```

### 做了什么

把 `(package-initialize)` 换成 `package-activate-all`。前者实测 0.135s，
后者 0.023s——差的 0.11s 全花在把 6700 多条归档索引读进内存。而**激活已装的
包并不需要那份索引**，只有装包需要。所以索引改成按需读，见
`my/ensure-archive-contents`；`M-x my/bootstrap-packages` 和
`M-x my/packages-status` 会自己触发它。效果：`my-packages` 从 0.185s 降到
0.081s。

注意由此带来的一个后果：启动后 `package-archive-contents` 是 `nil` 属于
**正常状态**，不代表没装包。判断依赖是否就绪看 `my/packages-ready`。

### 试过但不值得

字节编译 `lisp/*.el` 只省 0.03s（约 4%），却要背上 `.elc` 过期的风险：`.elc`
比 `.el` 新时 Emacs 优先加载它，改完配置忘了重编译就是在跑旧代码。`*.elc`
仍然留在 gitignore 里，别往仓库里塞。

剩下的大头是 `my-ui` 的 0.072s，里面主要是字体探测和 `load-theme`——这两样
必须在首帧之前完成，延后只会换来启动后一次可见的跳变，所以不动。

## 键位速查

默认是**原生 Emacs 键位**，没有 evil。理由：不打模式，中文输入不需要换来换去。

| 键 | 作用 |
| --- | --- |
| `C-x C-e` | 求值光标前那个表达式（改配置全靠它） |
| `M-:` | 随手求值一个表达式 |
| `C-x b` | 切换 buffer（consult，带预览） |
| `C-s` | 搜索当前文件（consult-line，带预览） |
| `C-c t` | 在 rose-pine 三个变体间切换 |
| `C-c i` | 跳到当前文件的标题/函数（consult-imenu） |
| `C-c g` | 在项目根目录打开 lazygit；再按一次切回同一个实例 |
| `C-.` / `C-;` | 对当前补全候选做操作 / 直接执行它的默认动作（embark） |
| `C-\` | 切换输入法；`C-u C-\` 选具体方案 |
| `C-h k` | 这个键是干什么的 |
| `C-h f` / `C-h v` | 查函数 / 变量文档 |
| `M-.` / `M-,` | 跳到定义 / 跳回来（xref，由 LSP 提供） |
| `M-g M-n` | 跳到 `*compilation*` 里的下一个错误 |
| `C-c C-e` | 列出当前项目的所有符号（consult-eglot，LSP 连上后可用） |

Markdown 里（`markdown-mode` 自带，未改动）：

| 键 | 作用 |
| --- | --- |
| `C-c C-l` / `C-c C-i` | 插入或编辑链接 / 图片 |
| `C-c C-s` | 样式前缀（加粗、斜体、引用…） |
| `C-c C-x` | 各类开关（行内图片预览等） |
| `C-c C-c p` | 预览（调 pandoc，在浏览器里打开） |
| `C-c C-c e` | 导出 |
| `TAB` / `S-TAB` | 折叠/展开标题（和 org-mode 一致） |
| `C-c '` | 把代码块拿到独立 buffer 里按真实语言编辑 |
| `C-c C-h` | 列出当前 buffer 的全部按键 |

代码那边不另设键位表：补全（corfu，边打边弹；`TAB` 也可手动触发）、跳转、重命名、
格式化都走 eglot 的默认绑定，和 Emacs 原生那套一致。两个语言各自只多一件事：

| 语言 | 保存时自动格式化 | 依赖的外部程序 |
| --- | --- | --- |
| Rust | `rustfmt`（apheleia，异步） | `rust-analyzer`、`rustfmt`，都是 rustup 组件 |
| Zig | `zig fmt --stdin`（apheleia，异步） | `zls`，单独安装并放进 PATH |

## 主题

`themes/` 里是照[官方色板](https://rosepinetheme.com/palette/)自己写的，
色值直接取自 `rose-pine-palette` 的 `dist/css/rose-pine.css`，没有改动。
`C-c t` 在三个变体间切换：

| 变体 | 底色 | 适合 |
| --- | --- | --- |
| `rose-pine` | `#191724` | 默认，深色 |
| `rose-pine-moon` | `#232136` | 更偏紫的深色 |
| `rose-pine-dawn` | `#faf4ed` | 白天、长文 |

### 为什么自己写而不是用现成的移植

社区那个 `thongpv87/rose-pine-emacs` 能用，但：

- 停在 2023 年底的 v0.2，依赖 `autothemer`，且不在任何 ELPA 里；
- 把 `outline-1..8` 和 `bold` 全都设成 `#555169`（nano-emacs 的极低对比审美），
  **标题和加粗会灰成一片** —— 这正好是写文档时最不能忍的地方；
- 源码里有拼写错误（`:foregroud`）和括号错位。

自己写之后：没有额外依赖，标题按层级用 iris / foam / rose，加粗是正文色加粗，
`markdown-*` 那一组脸面也能按写作需要单独调。

### 改配色

所有色值集中在 `rose-pine-common.el` 顶部的 `rose-pine-palettes`。
改完保存，`M-x load-theme` 选一次对应变体即可。

脸面分三组，加新脸面时对号入座：

| 变量 | 什么时候用 |
| --- | --- |
| `rose-pine--core-faces` | Emacs 启动就存在的脸面 |
| `rose-pine--markdown-faces` | 等 `markdown-mode` 加载后才有 |
| `rose-pine--package-faces` | 按库分组，等对应包加载后才应用 |

> 注意：给**还没定义**的脸面设色会报 `Invalid face`。所以 markdown、outline、
> diff 这些必须挂在 `with-eval-after-load` 上，`rose-pine--apply` 也会跳过未定义的脸面。

## 字体

`lisp/my-ui.el` 顶部四个变量：

```elisp
(defvar my/latin-font "JetBrainsMono NF")      ; 首选名
(defvar my/cjk-font "Noto Serif SC")
(defvar my/latin-font-fallbacks '("JetBrainsMono Nerd Font" ...))
(defvar my/cjk-font-fallbacks   '("Noto Serif CJK SC" ...))
(defvar my/latin-size 110)
(defvar my/cjk-size 125)
```

字体名在 Windows 和 Linux 上不一样，而**名字对不上时 Emacs 不报错、直接用回退
字体**——所以 `my/apply-fonts` 会用 `find-font` 在候选列表里挑第一个真正装了的，
换机器不用改这里。改完 `C-x C-e` 求值 `(my/apply-fonts)` 立刻生效（它现在是
interactive 的，`M-x my/apply-fonts` 也行）。

首帧建好之前字体列表未必枚举得到（batch、daemon、某些 GUI 启动路径），所以
`window-setup-hook` 里还会再应用一次。

- 中文比拉丁字号大一档（11pt / 12.5pt），是为了让两种字的**视觉大小**对齐；
  同样的 pt 下汉字会显得偏小。
- 想换中文字体，改 `my/cjk-font`。这台机器上已装的有 `Noto Serif SC`、
  `Noto Sans SC`、等线、雅黑、宋体。
- 如果能接受中英等宽对齐，装[更纱黑体](https://github.com/be5invis/Sarasa-Gothic)
  的 `Sarasa Term SC`，把 `my/cjk-font` 换成它，等宽场景会更整齐。
- 字体名要用 **Windows 注册名**（如 `JetBrainsMono NF`），不是文件名
  （`JetBrainsMonoNerdFont-Regular.ttf`）。

## 已知取舍

- **`C-s` 被 `consult-line` 接管**，不再是 `isearch`。想退回：
  `(keymap-global-set "C-s" #'isearch-forward)`。
- **中文 Markdown 不要用 `auto-fill-mode`**。它插入的是真实换行，GitHub 会把段落
  拆开，中文没有空格，拆完很难看。配置里用 `visual-line-mode` 做软换行。
- **`olivetti` 只在 markdown 里开**，代码 buffer 里居中窄栏是负担。
  宽度 `olivetti-body-width` 单位是「列」，一个汉字占两列，90 列 ≈ 45 个汉字。
- **`valign` 按显示宽度对齐表格**，中文表格基本靠它。官方说明：超过 4000 字符的
  大表格不处理，≥100 行会卡。
- **没装 pandoc 时**预览/导出会报错，但编辑、折叠、补全都不受影响。
- **tree-sitter 语法库不在 Emacs 发行包里**。官方 Windows 构建只带
  `libtree-sitter.dll`，语法库要自己编译安装；没装时 `rust-ts-mode` 能打开文件，
  但基本没有高亮（`*Warnings*` 里会有一行 grammar 提示）。
- **格式化交给外部程序**。apheleia 异步跑 `rustfmt` / `zig fmt --stdin`，
  输入不会被打断；但程序不在 PATH 上时，保存会在 echo area 报
  `Could not find executable`，文件内容不受影响。
- **没有装调试器**。需要断点调试时上 `dape`（GNU ELPA），当前刻意留白。

## 文案约定

- **echo area / minibuffer 里的提示一律英文**。中英混排会撑高行高、基线也对不齐，
  在只有一行的 minibuffer 里特别明显。
- 注释、docstring、`*my-packages*` 这种报告 buffer 用中文——那里有整块空间，
  中文描述更省字数。
- 主题名里的 `é`（`Rosé Pine`）保留，它属于拉丁字母，不是混排问题。

## 排错

| 症状 | 看什么 |
| --- | --- |
| **所有源都是 0.2 秒 fail** | 十有八九是 CA 证书没配：`M-: gnutls-trustfiles` 看那些路径是否全都不存在。`my/ensure-ca-bundle` 会自动换成 Git 自带的 bundle，见上文 |
| **卡在 `Contacting host: ...:443`，`C-g` 也按不动** | 这是老版本的问题。现在探测和下载都在子进程里，父进程到点就 kill，不会再卡住。真遇到卡死先结束 `emacs.exe`，再 `M-x my/diagnose-network` |
| **想知道哪个地址会挂住** | `M-x my/diagnose-network`。每个候选一行：`ok` / `fail` / `TIMEOUT (would hang Emacs)` + 耗时 |
| **代理换了端口** | 默认不用代理。要用就 `(setq my/use-proxy t)`，每次启动重新读注册表；`M-x my/apply-proxy` 立即刷新，`M-x my/packages-status` 看当前值 |
| **代理拦了某个源** | `my/bootstrap-packages` 会换下一个候选；全挂时会自动**退回直连**再试一轮 |
| **不用代理** | 默认就是直连。想手动指定端口：`(setq my/proxy-override "127.0.0.1:7897")`（优先于系统设置） |
| **启动后界面毫无变化** | 先看 Emacs 到底读哪个目录：`M-: (expand-file-name "~")`。Windows 上没设 `HOME` 时它是 `c:/Users/<你>/AppData/Roaming`，配置就该在 `%APPDATA%\.emacs.d`——确认那里也是 junction，见根 README |
| **起来了但没有补全 / `.md` 不进 markdown-mode / 主题不对** | `M-: my/packages-ready`。为 `nil` 说明第三方配置整段被跳过——它只能由 `my-packages.el` 在 `package-initialize` 之后设置，别在 `init.el` 里提前算（那时索引还是空的，算出来永远 `nil`） |
| **`C-c g` 没反应 / 报找不到程序** | `M-: (executable-find "lazygit")`。不在 PATH 上会直接 `user-error` 报出来，不会静默失败 |
| 启动慢 / 想量化 | `M-x emacs-init-time`（正常应 < 1 秒，因为它不联网） |
| 报错信息 | `*Messages*` buffer |
| 启动时某步失败 | `M-x toggle-debug-on-error` 再复现，会弹 backtrace |
| 哪些依赖没装上 | `M-x my/packages-status` |
| 索引过期 | 重跑 `M-x my/bootstrap-packages`（不要用裸的 `M-x package-refresh-contents`，它没有失败切换，也不在子进程里） |
| 字体没生效 | `C-h v my/latin-font`，确认名字是注册名而非文件名 |
| **打开 `.rs` / `.zig` 几乎没高亮** | 语法库没装：`M-: (treesit-language-available-p 'rust)` 为 `nil` 就跑 `M-x my/install-treesit-grammars`；失败时看 `*Messages*` 里是 git 还是编译器的问题 |
| **LSP 没连上**（modeline 没有 eglot 标识） | `M-x eglot` 手动起一次，看报什么；`rust-analyzer` / `zls` 必须在 PATH 上。zig 那边还要确认 `zig-ts-mode` 已登记到 `eglot-server-programs` |
| **保存后代码被格式化坏 / 没格式化** | `M-x apheleia-mode` 开关对比；`M-: (alist-get 'zig-ts-mode apheleia-mode-alist)` 看映射是否生效 |
| **`zig-ts-mode` 找不到** | `M-x my/packages-status` 看它是否 `ok`；它在 MELPA 上，源不通就 `C-u M-x my/bootstrap-packages` 重刷索引 |

## 调试

Emacs 自带的几个工具，排配置问题时按需取用：

| 目的 | 做法 |
| --- | --- |
| 给一个表达式计时 | `M-: (benchmark-run 1 (…))` |
| 跟踪函数调用与参数 | `M-x trace-function-background RET 函数名 RET`，输出在 `*trace-output*` |
| 出错时进 debugger | `M-x toggle-debug-on-error`，再复现 |
| 按 `C-g` 进 debugger | `M-x toggle-debug-on-quit` |
| 单函数步进 | 光标停在 defun 里 `C-u C-M-x`，然后调用它 |
| 看 url 在做什么 | `M-: (setq url-debug t)`，之后看 `*URL-DEBUG*` |
| 看性能 | `M-x profiler-start` → 复现 → `M-x profiler-report` |

**关键限制**：以上全部依赖 Emacs 回到 Lisp 事件循环。一旦卡在 C 层
（DNS 解析、TLS 握手），Emacs 既不会跑超时逻辑，也不会处理 `C-g`——
这就是为什么装包的探测和下载都放在**子进程**里（`my/run-bounded` 到点
`kill`），而不是在 Emacs 里设超时。

另外：**启动慢**先跑 `M-x my/startup-report`，它给出每个模块的加载耗时；
超过 3 秒时启动过程也会主动提示一次。常见元凶是 `recentf` 在启动时逐个
`stat` 文件（网络路径会卡很久），配置里已经关掉了自动清理。

## 还没做的

- **中文输入法**：内置的 `C-\` + `chinese-py` 现在就能用。更顺手的是
  [emacs-rime](https://github.com/DogLooksGood/emacs-rime)，直接接小狼毫的
  librime 和词库，靠 predicate 控制「normal state 时不激活」。
- **拼写检查**：`jinx` 在 Windows 需要 libenchant，值得单独折腾一轮。
- **预览自动刷新**：`markdown-preview-mode` 或 `grip` 可以做到改一处刷一次。
