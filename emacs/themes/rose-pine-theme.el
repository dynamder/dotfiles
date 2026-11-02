;;; rose-pine-theme.el --- Rosé Pine 主变体（深色） -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; Rosé Pine 的主变体。调色板和全部脸面定义都在 rose-pine-common.el，
;; 三个变体共用同一份实现，这里只负责把它"注册"成一个主题。
;;
;; 用法：
;;   (add-to-list 'custom-theme-load-path "~/.emacs.d/themes/")
;;   (load-theme 'rose-pine t)

;;; Code:

(deftheme rose-pine "Rosé Pine — 官方色板 (#191724 / #e0def4) 的 Emacs 实现。")

(require-theme 'rose-pine-common)
(rose-pine--define 'rose-pine 'main)

(provide-theme 'rose-pine)

;;; rose-pine-theme.el ends here
