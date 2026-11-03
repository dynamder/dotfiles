;;; init.el --- 个人 Emacs 配置入口 -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; 这个文件只做装配，具体内容分在 lisp/ 下：
;;
;;   my-packages.el    包源、代理、探测/下载、M-x my/bootstrap-packages
;;   my-ui.el          字体、主题、窗口外观、modeline
;;   my-completion.el  补全与搜索
;;   my-markdown.el    markdown 写作环境
;;   my-git.el         git：用 lazygit 当界面（C-c g）
;;   my-treesit.el     tree-sitter 语法库：源地址、编译器、M-x my/install-treesit-grammars
;;   my-rust.el        Rust：rust-ts-mode + eglot + rustfmt
;;   my-zig.el         Zig：zig-ts-mode + zls + zig fmt
;;
;; 启动路径上不联网、不 spawn 进程。装包是显式命令。
;; 改哪一块就 C-x C-e 求值哪一块，不用重启。

;;; Code:

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(defvar my/load-times nil
  "各模块加载耗时，形如 ((模块 . 秒) ...)，供 `my/startup-report' 查看。")

(defvar my/pre-init-total
  (and before-init-time (float-time (time-since before-init-time)))
  "进入 init.el 之前已经花掉的时间（进程启动 + dump + early-init）。
在这台机器上若它偏大，说明慢在 Emacs 自身而不是配置。")

(defvar my/init-total nil
  "启动总耗时（秒）。在 `after-init-hook' 里记下——必须那时算，不能等用户调用
报告命令时现算，否则算的是「启动完到现在过了多久」。")

(defun my/startup-report ()
  "显示启动耗时拆解：进入 init 前 / 各模块 / init 之后，排「启动慢」用。"
  (interactive)
  (let* ((total (or my/init-total
                    (and before-init-time (time-since before-init-time))))
         (total (float-time total))
         (pre (or my/pre-init-total 0))
         (sum (apply #'+ (mapcar #'cdr my/load-times)))
         (post (max 0 (- total pre sum))))
    (message "startup %.2fs (before-init %.2fs, modules %.2fs, after %.2fs) | %s"
             total pre sum post
             (mapconcat (lambda (c) (format "%s %.2fs" (car c) (cdr c)))
                        (reverse my/load-times)
                        " | "))))

;; 依赖是否就绪由 my-packages.el 判断——只有它 `package-initialize' 之后
;; 才看得见索引缓存里有什么。这里只提供一个默认值，免得别的模块读到 void。
;;
;; **不要**在这个位置自己算：这一刻 `package-archive-contents' 还是空的，
;; 算出来永远是 nil，下面所有 `(when my/packages-ready ...)' 的整段会被静默
;; 跳过（vertico / markdown-mode / apheleia 全不加载，但 Emacs 照样起来）。
(require 'package)
(defvar my/packages-ready nil
  "第三方依赖是否就绪。由 my-packages.el 在 `package-initialize' 之后设置。")

;; 任何一个模块炸掉都不该让整个 Emacs 起不来。
;; my-ui 里"不依赖包"的部分（字体、主题、窗口）排在 modeline 之前，
;; 所以即使依赖缺失，外观设置也照样生效。
(dolist (module '(my-packages my-ui my-completion my-markdown
                  my-git my-treesit my-rust my-zig))
  (let ((t0 (float-time)))
    (condition-case err
        (require module)
      (error
       (if my/packages-ready
           (message "Module %s failed: %s" module (error-message-string err))
         (message "Module %s skipped (dependencies missing)" module))))
    (push (cons module (- (float-time) t0)) my/load-times)))

;; Customize 界面写出来的东西单独存，别污染这个文件。
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file t t))

;; 启动总耗时必须在「启动结束的那一刻」记下来。
;; 不能用 `(time-since before-init-time)' 在报告命令里现算——那算的是
;; 「启动完之后又过了多久」，用户过一会儿再看就会得到几十秒的假数字。
;; 用具名函数挂 hook，重复 load 这个文件也不会叠加。
(defun my/--record-init-time ()
  "在启动结束时记录总耗时。"
  (when (and before-init-time after-init-time)
    (setq my/init-total
          (float-time (time-subtract after-init-time before-init-time)))
    (when (> my/init-total 3)
      (message "Slow startup: %.1fs. Run M-x my/startup-report for a breakdown."
               my/init-total))))

(add-hook 'after-init-hook #'my/--record-init-time)

;; 放在最后，让它留在 echo area 里。
(unless my/packages-ready
  (message "Dependencies missing: run M-x my/bootstrap-packages, then restart Emacs."))

;;; init.el ends here
