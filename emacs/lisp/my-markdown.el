;;; my-markdown.el --- Markdown 写作环境 -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; 写中文 Markdown 有两个硬约束，这个文件的配置基本都围着它们转：
;;
;; 1. 不要用 auto-fill 插真实换行。
;;    GitHub 之类的渲染器会把段落里的换行当成分段，中文又没有空格，
;;    插了换行排版会碎掉。所以要软换行：visual-line-mode。
;;
;; 2. 表格必须用 valign 做视觉对齐。
;;    一个汉字占两列，纯文本对齐（markdown-mode 默认那种）一定歪。
;;    valign 是按显示宽度渲染的，中英混排的表格才对得齐。
;;
;; 预览要外部渲染器，优先 pandoc。没有 pandoc 时 markdown-mode 的预览和导出
;; 会报错，但编辑、补全、折叠这些都不受影响。
;;
;; 这里同样没有 :ensure，原因见 my-packages.el：装包是显式动作。

;;; Code:

;;; ---------------------------------------------------------------------------
;;; 写作模式的开关（纯内置，不依赖包）
;;; ---------------------------------------------------------------------------

(defun my/markdown-setup ()
  "进入 markdown 之后的写作环境设置。"
  ;; 软换行：只影响显示，不动文件内容
  (visual-line-mode 1)
  (setq-local truncate-lines nil)
  ;; 中文段落行距再放松一点，比代码里舒服
  (setq-local line-spacing 0.25)
  ;; 中文标点后面不应该有「西文句末要两个空格」的假设
  (setq-local sentence-end-double-space nil))

(add-hook 'markdown-mode-hook #'my/markdown-setup)

;;; ---------------------------------------------------------------------------
;;; 依赖包
;;; ---------------------------------------------------------------------------

(when (bound-and-true-p my/packages-ready)

  ;; markdown 本体
  (use-package markdown-mode
    :mode (("\\.md\\'"       . markdown-mode)
           ("\\.markdown\\'" . markdown-mode)
           ("README\\.md\\'"  . gfm-mode))
    :custom
    (markdown-fontify-code-blocks-natively t) ; 代码块里按对应语言着色
    (markdown-enable-math t)                  ; 支持 $...$ / $$...$$
    (markdown-list-indent-width 2)
    (markdown-hide-markup nil)                ; 中文写作时保留标记更踏实
    :config
    ;; 有 pandoc 就用它渲染预览 / 导出，没有就保持默认命令
    (when (executable-find "pandoc")
      (setq markdown-command "pandoc -f gfm -t html5 --standalone")))

  ;; C-c ' 把代码块拿到独立 buffer 里按真实语言编辑
  (use-package edit-indirect
    :defer t)

  ;; 正文用比例字体（Noto Serif SC），代码和代码块保持等宽
  (use-package mixed-pitch
    :hook (markdown-mode . mixed-pitch-mode))

  ;; 居中窄栏。注意 olivetti-body-width 的单位是「列」，
  ;; 一个汉字占两列，所以 90 列大约是一行 45 个汉字。
  (use-package olivetti
    :custom
    (olivetti-body-width 90)
    :hook (markdown-mode . olivetti-mode))

  ;; 按显示宽度对齐表格：中文表格能不能看，全靠它
  (use-package valign
    :hook ((markdown-mode . valign-mode)
           (org-mode      . valign-mode))))

(provide 'my-markdown)
;;; my-markdown.el ends here
