;;; my-rust.el --- Rust 开发环境 -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; Rust 这边几乎不用装东西，Emacs 30 内置的两样就够了：
;;
;;   rust-ts-mode  tree-sitter 语法高亮（Emacs 29 起内置）
;;   eglot         30 起自带 (rust-analyzer) 预设，不用手写启动命令
;;
;; 编辑器外面需要的东西（本机已就绪，换机器时照这个清单查）：
;;
;;   rustup component add rust-analyzer
;;   rustup component add rustfmt
;;
;; 还有一个前提容易被忽略：**rust-ts-mode 依赖 tree-sitter 的 rust 语法库**。
;; 没装的话文件照样能打开，但只剩最基本的字体锁，等于没有高亮。
;; 装法：M-x treesit-install-language-grammar → rust（需要 PATH 上有 C 编译器）。
;;
;; 编译和测试不装插件：M-x compile 里写 cargo build / cargo test，
;; 输出落在 *compilation* 里，M-g M-n 跳到下一个错误。比专门的 cargo UI
;; 少一层抽象，而且换项目也不用改配置。

;;; Code:

(when (bound-and-true-p my/packages-ready)

  (use-package rust-ts-mode
    :mode ("\\.rs\\'" . rust-ts-mode)
    :hook (rust-ts-mode . eglot-ensure))

  ;; 保存时跑 rustfmt。apheleia 是异步的，输入不会被格式化进程卡住，
  ;; 也不会像「保存时同步调外部命令」那样在远程/大文件上抖一下。
  (use-package apheleia
    :hook (rust-ts-mode . apheleia-mode)
    :config
    ;; 内置表里通常只登记了 rust-mode，rust-ts-mode 自己补一条更可控。
    (add-to-list 'apheleia-mode-alist '(rust-ts-mode . rustfmt))))

(provide 'my-rust)
;;; my-rust.el ends here
