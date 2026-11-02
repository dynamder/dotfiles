;;; rose-pine-moon-theme.el --- Rosé Pine Moon 变体 -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; Rosé Pine 的 moon 变体：底色比主变体偏紫一点（#232136），
;; 其余结构完全一致，共用 rose-pine-common.el。

;;; Code:

(deftheme rose-pine-moon "Rosé Pine Moon — 官方色板 (#232136 / #e0def4)。")

(require-theme 'rose-pine-common)
(rose-pine--define 'rose-pine-moon 'moon)

(provide-theme 'rose-pine-moon)

;;; rose-pine-moon-theme.el ends here
