;;; my-treesit.el --- tree-sitter 语法库的编译与安装 -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; Emacs 发行包只带 libtree-sitter.dll，各语言的语法库要自己编。这里管三件事：
;;
;; 1. 源地址。`treesit-language-source-alist' 在 Emacs 30 里默认是空的，
;;    不填就得每次交互输入仓库地址。
;; 2. 编译器。本机 Windows 没有 gcc，借 Zig 的 `zig cc'；但 zig 把对象文件
;;    命名成 .obj，而 treesit 链接时只按 *.o 收集，所以 bin/cc.bat 在编译后
;;    会把 .obj 改名成 .o。
;; 3. 一条命令装齐，不用记住四个语言名和四段地址。
;;
;; 包装脚本跟着仓库走，不依赖 PATH 上有 cc：路径由 `user-emacs-directory'
;; 算出来，换机器 clone 完就能用（前提是 zig 本体在 PATH 上）。
;; 非 Windows 平台不需要这套，`my/treesit-cc-program' 会是 nil，
;; 一切退回 treesit 的默认行为。

;;; Code:

(require 'treesit)

(defvar my/treesit-grammars
  '((rust "https://github.com/tree-sitter/tree-sitter-rust")
    (zig "https://github.com/tree-sitter-grammars/tree-sitter-zig")
    ;; markdown 是 monorepo，两个语法库靠第四项 source-dir 区分；
    ;; 只影响 zig 文档注释里的 Markdown 高亮，装不上也不影响写 zig。
    (markdown "https://github.com/tree-sitter-grammars/tree-sitter-markdown"
              nil "tree-sitter-markdown")
    (markdown_inline "https://github.com/tree-sitter-grammars/tree-sitter-markdown"
                     nil "tree-sitter-markdown-inline"))
  "要装的语法库，每项形如 (语言 仓库地址 &optional 版本 源码子目录)。")

(defvar my/treesit-cc-program
  (let ((file (expand-file-name "bin/cc.bat" user-emacs-directory)))
    (and (eq system-type 'windows-nt)
         (file-exists-p file)
         file))
  "编译语法库用的 C 编译器。
nil 表示不干预，交给 `treesit-install-language-grammar' 自己找 cc。")

(defvar my/treesit-cxx-program
  (let ((file (expand-file-name "bin/c++.bat" user-emacs-directory)))
    (and (eq system-type 'windows-nt)
         (file-exists-p file)
         file))
  "编译语法库用的 C++ 编译器，只在语法库带 scanner.cc 时才会用到。")

;; 自己的配方排前面：即使 Emacs 以后往默认值里加了同名条目，也用这里的。
(setq treesit-language-source-alist
      (append my/treesit-grammars
              (seq-filter (lambda (entry)
                            (not (assq (car entry) my/treesit-grammars)))
                          treesit-language-source-alist)))

(defun my/treesit--prefer-repo-cc (orig out-dir lang &optional url revision source-dir cc c++)
  "让语法库编译走仓库自带的包装脚本。
调用方显式指定了 CC / C++ 时不覆盖。"
  (funcall orig out-dir lang url revision source-dir
           (or cc my/treesit-cc-program)
           (or c++ my/treesit-cxx-program)))

;; `treesit--install-language-grammar-1' 是内部函数，但这层包装没有公开替代：
;; `treesit-install-language-grammar' 只在配方缺失时才问编译器，问了也只记一
;; 个会话，所以只能在这里换掉。函数改名时这里会自动失效（不报错），
;; 那时退回「PATH 上要有 cc」即可。
(when (fboundp 'treesit--install-language-grammar-1)
  (advice-add 'treesit--install-language-grammar-1 :around
              #'my/treesit--prefer-repo-cc))

(defun my/install-treesit-grammars (&optional force)
  "装 `my/treesit-grammars' 里还没装的语法库。
前缀参数 FORCE 非 nil 时全部重装。装完重开文件才生效。"
  (interactive "P")
  (dolist (entry my/treesit-grammars)
    (let ((lang (car entry)))
      (if (and (not force) (treesit-language-available-p lang))
          (message "%s: already installed" lang)
        (message "%s: installing..." lang)
        (condition-case err
            (progn
              (treesit-install-language-grammar lang)
              (message "%s: %s" lang
                       (if (treesit-language-available-p lang)
                           "ok"
                         "built, but not loadable")))
          (error (message "%s: failed: %s" lang (error-message-string err)))))))
  (message "Done. Reopen the buffer to pick up new grammars."))

(provide 'my-treesit)
;;; my-treesit.el ends here
