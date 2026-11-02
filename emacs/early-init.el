;;; early-init.el --- 启动最早期设置 -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; 这个文件在 GUI 帧创建之前、package 系统初始化之前执行。
;; 只放那些「必须赶在前面」的东西：关掉自带的界面元素、把字体定好，
;; 这样启动时不会先出现一个丑窗口再变样。

;;; Code:

;; --- 启动画面 ---------------------------------------------------------------
;; 关掉 GNU Emacs 的启动画面和 *scratch* 里的提示文字。
(setq inhibit-startup-screen t
      inhibit-startup-echo-area-message user-login-name
      initial-scratch-message nil)

;; package 系统由 init.el 里的 my-packages.el 负责，别加载两次。
(setq package-enable-at-startup nil)

;; 字体一旦定好就别再让 Emacs 为了它重算窗口大小。
(setq frame-inhibit-implied-resize t)

;; --- 窗口外观（必须在帧创建前设置）------------------------------------------
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(push '(horizontal-scroll-bars) default-frame-alist)
;; 四周留白 + 细分隔线，这是「不违和」的关键一笔。
(push '(internal-border-width . 12) default-frame-alist)
(push '(right-divider-width . 1) default-frame-alist)
(push '(bottom-divider-width . 1) default-frame-alist)

;; 等宽字体在帧创建时就定下来。具体的中文字号在 lisp/my-ui.el 里补。
;; 这里只管首帧，所以按平台给名字：同一个 Nerd Font 在 Windows 注册成
;; "JetBrainsMono NF"，在 Arch 上是 "JetBrainsMono Nerd Font"。真正的候选
;; 探测和中文回退都在 my-ui.el 里。
(add-to-list 'default-frame-alist
             (cons 'font (if (eq system-type 'windows-nt)
                             "JetBrainsMono NF-11"
                           "JetBrainsMono Nerd Font-11")))

;;; early-init.el ends here
