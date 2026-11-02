;;; my-ui.el --- 字体、主题、modeline -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; 「界面违和」这件事，主题只解决一半。真正决定观感的是：
;;   1. 字体（拉丁/中文分别选，中文字号要大一档）
;;   2. modeline（默认那条色块是违和感的主要来源）
;;   3. 窗口留白与分隔线
;;   4. 滚动和平滑度
;; 所以这个文件按这四项组织。

;;; Code:

;;; ---------------------------------------------------------------------------
;;; 一、字体
;;; ---------------------------------------------------------------------------

;; 这台机器上已装的字体（用 Windows 字体注册名，不是文件名）：
;;   JetBrainsMono NF    等宽，带 Nerd 图标，doom-modeline 靠它
;;   Noto Serif SC       中文衬线，长文阅读比黑体舒服
;;   Noto Sans SC        中文黑体，想换无衬线就改下面一行
(defvar my/latin-font "JetBrainsMono NF")
(defvar my/cjk-font "Noto Serif SC")

;; 单位是 1/10 pt。中文字号比拉丁大一档，视觉上才一样大。
(defvar my/latin-size 110)
(defvar my/cjk-size 125)

(defun my/apply-fonts ()
  "把字体设置应用到默认脸面。
改完 my/latin-font / my/cjk-font 之后 C-x C-e 求值本函数即可生效。"
  (set-face-attribute 'default nil :family my/latin-font :height my/latin-size)
  (set-face-attribute 'fixed-pitch nil :family my/latin-font :height my/latin-size)
  (set-face-attribute 'variable-pitch nil :family my/cjk-font :height my/cjk-size)
  ;; 等宽字体里没有汉字，需要给 han 这个 charset 单独指定回退字体。
  (set-fontset-font t 'han (font-spec :family my/cjk-font :size (/ my/cjk-size 10.0))))

(my/apply-fonts)

;; Windows 上字体缓存不压缩的话，切字体和启动会明显卡顿。
(setq inhibit-compacting-font-caches t)

;; 行距稍放松一点，中文多行段落会好读很多。浮点数表示相对字高的比例。
(setq-default line-spacing 0.15)

;;; ---------------------------------------------------------------------------
;;; 二、主题
;;; ---------------------------------------------------------------------------

;; themes/ 目录里是自己写的 rose-pine（见 rose-pine-common.el 的注释）。
;; 三个变体都在，切换用 C-c t。
(add-to-list 'custom-theme-load-path
             (expand-file-name "themes/" user-emacs-directory))

(defun my/switch-rose-pine ()
  "在 rose-pine 的三个变体之间切换。"
  (interactive)
  (let* ((choices '((?d . rose-pine)        ; dark 主变体
                    (?m . rose-pine-moon)   ; 更紫一点的深色
                    (?l . rose-pine-dawn))) ; 浅色
         (pick (read-char-choice
                "Rose Pine: [d] main  [m] moon  [l] dawn  "
                (mapcar #'car choices)))
         (theme (alist-get pick choices)))
    (mapc #'disable-theme (copy-sequence custom-enabled-themes))
    (load-theme theme t)
    (message "Switched to %s" theme)))

(condition-case err
    (load-theme 'rose-pine t)
  (error (message "Failed to load rose-pine, using default: %s" (error-message-string err))))

;;; ---------------------------------------------------------------------------
;;; 三、窗口与交互
;;;
;;; 顺序说明：所有不依赖第三方包的设置都排在 modeline 之前。这样即使依赖
;;; 没装好（首次启动），字体、主题、窗口这些也照样生效，不会因为
;;; use-package 失败而丢掉后面半截配置。
;;; ---------------------------------------------------------------------------

;; 默认的编辑体验补丁
(delete-selection-mode 1)          ; 选中后直接输入即替换
(electric-pair-mode 1)             ; 自动配对括号
(global-hl-line-mode 1)            ; 高亮当前行
(column-number-mode 1)             ; 显示列号（中文对齐时有用）
(setq-default cursor-type 'bar)    ; 竖线光标，比方块现代
(blink-cursor-mode -1)
(setq ring-bell-function 'ignore)  ; 别响
(setq use-short-answers t)         ; y/n 而不是 yes/no
(setq confirm-kill-emacs #'y-or-n-p)
(setq sentence-end-double-space nil) ; 中文写作里句号后面就是一个空格
(setq-default fill-column 80)

;; 平滑滚动（需要图形界面）
(when (display-graphic-p)
  (setq scroll-conservatively 101
        scroll-margin 2)
  (when (fboundp 'pixel-scroll-precision-mode)
    (setq pixel-scroll-precision-use-momentum nil)
    (pixel-scroll-precision-mode 1)))

;; 备份文件和自动保存别丢进项目目录（.emacs.d 本身就是 dotfiles 仓库）
(let ((backup (expand-file-name "backup/" user-emacs-directory))
      (autosave (expand-file-name "auto-save/" user-emacs-directory)))
  (make-directory backup t)
  (make-directory autosave t)
  (setq backup-directory-alist `(("." . ,backup))
        auto-save-file-name-transforms `((".*" ,autosave t))
        create-lockfiles nil))

;;; ---------------------------------------------------------------------------
;;; 四、modeline
;;;
;;; 放在最后，并且整段用 my/packages-ready 挡住：
;;;   - 依赖没装时不去碰网络（:ensure 会主动 refresh，绝对不能留）；
;;;   - 也不会因为命令不存在而报错；
;;;   - 前面的字体/主题/窗口设置不受影响。
;;; ---------------------------------------------------------------------------

(when (bound-and-true-p my/packages-ready)

  (use-package nerd-icons
    :custom (nerd-icons-scale-factor 1.0))

  (use-package doom-modeline
    :custom
    (doom-modeline-height 26)
    (doom-modeline-bar-width 4)
    (doom-modeline-icon t)
    (doom-modeline-major-mode-icon t)
    (doom-modeline-buffer-file-name-style 'truncate-upto-project)
    (doom-modeline-minor-modes nil)
    :hook (after-init . doom-modeline-mode)))

(provide 'my-ui)
;;; my-ui.el ends here
