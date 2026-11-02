;;; my-zig.el --- Zig 开发环境 -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; Zig 没有内置 major mode，用 MELPA 的 zig-ts-mode：
;;
;;   - 基于 tree-sitter，要求 Emacs 30.1 及以上
;;   - 自带 M-x zig-ts-install-grammars，一次装好 zig 语法库
;;   - /// 文档注释里的 Markdown 会被高亮，前提是 markdown 和
;;     markdown_inline 两个语法库也在（顺序上是先 zig 后 markdown）
;;
;; eglot 的 zls 预设只登记了老的 zig-mode（`(zig-mode . ("zls"))'），
;; 不认 zig-ts-mode，所以要补一行。zls 需要单独装并放进 PATH。
;;
;; 备选是官方 zig-mode（NonGNU ELPA）：更保守，但没有 tree-sitter，
;; 只在 zig-ts-mode 本身出问题时才退回去。

;;; Code:

(when (bound-and-true-p my/packages-ready)

  (use-package zig-ts-mode
    :mode ("\\.zig\\'" . zig-ts-mode)
    :hook (zig-ts-mode . eglot-ensure)
    :config
    (with-eval-after-load 'eglot
      (add-to-list 'eglot-server-programs
                   '(zig-ts-mode . ("zls")))))

  (use-package apheleia
    :hook (zig-ts-mode . apheleia-mode)
    :config
    ;; 不指望 apheleia 内置表里一定有 zig，自己声明一条更可控：
    ;; `zig fmt --stdin' 从标准输入读源码、把格式化结果写到标准输出。
    (add-to-list 'apheleia-formatters '(zig "zig" "fmt" "--stdin"))
    (add-to-list 'apheleia-mode-alist '(zig-ts-mode . zig))))

(provide 'my-zig)
;;; my-zig.el ends here
