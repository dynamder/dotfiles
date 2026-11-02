;;; rose-pine-dawn-theme.el --- Rosé Pine Dawn 变体（浅色） -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; Rosé Pine 的 dawn 变体，唯一的浅色方案（#faf4ed / #575279）。
;; 白天写长文时比深色底舒服，其余结构完全一致。

;;; Code:

(deftheme rose-pine-dawn "Rosé Pine Dawn — 官方色板 (#faf4ed / #575279)。")

(require-theme 'rose-pine-common)
(rose-pine--define 'rose-pine-dawn 'dawn)

(provide-theme 'rose-pine-dawn)

;;; rose-pine-dawn-theme.el ends here
