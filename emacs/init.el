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
;;
;; 启动路径上不联网、不 spawn 进程。装包是显式命令。
;; 改哪一块就 C-x C-e 求值哪一块，不用重启。

;;; Code:

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(defvar my/load-times nil
  "各模块加载耗时，形如 ((模块 . 秒) ...)，供 `my/startup-report' 查看。")

(defvar my/packages-ready nil
  "第三方依赖是否可用。由下面计算，见 `my/bootstrap-packages'。")

(defun my/startup-report ()
  "显示各模块加载耗时和总启动时间，排「启动慢」用。"
  (interactive)
  (message "init total %.2fs | %s"
           (float-time (time-since before-init-time))
           (mapconcat (lambda (c) (format "%s %.2fs" (car c) (cdr c)))
                      (reverse my/load-times)
                      " | ")))

;; 依赖是否就绪 = 索引缓存存在 + 抽查一个包。
;; 没就绪时只跳过，不刷一屏 "Cannot open load file"。
;; 先 require package：下面用的两个函数都在它里面。
(require 'package)
(condition-case nil
    (setq my/packages-ready
          (and (bound-and-true-p package-archive-contents)
               (package-installed-p 'vertico)))
  (error (setq my/packages-ready nil)))

;; 任何一个模块炸掉都不该让整个 Emacs 起不来。
;; my-ui 里"不依赖包"的部分（字体、主题、窗口）排在 modeline 之前，
;; 所以即使依赖缺失，外观设置也照样生效。
(dolist (module '(my-packages my-ui my-completion my-markdown))
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

;; 启动明显变慢时给一句提示，附上 M-x my/startup-report 的入口。
(let ((total (float-time (time-since before-init-time))))
  (when (> total 3)
    (message "Slow startup: %.1fs. Run M-x my/startup-report for a breakdown." total)))

;; 放在最后，让它留在 echo area 里。
(unless my/packages-ready
  (message "Dependencies missing: run M-x my/bootstrap-packages, then restart Emacs."))

;;; init.el ends here
