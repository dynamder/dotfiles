;;; my-completion.el --- 补全与搜索 -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; 默认的 minibuffer 是 Emacs 观感最老旧的地方，也是这一套改动收益最大的地方。
;; vertico + orderless + marginalia + consult 四个加起来只要几十行，
;; 就能让 M-x、C-x C-f、切换 buffer 全部变成现代编辑器的手感。
;;
;; vertico   竖直排列的补全列表
;; orderless 空格分隔关键词，顺序无关（像 fzf）
;; marginalia 在补全列表右侧显示文档、文件大小等信息
;; consult   把搜索/跳转类命令接到这套补全上
;;
;; 注意这里**没有** :ensure。use-package 的 :ensure 在包缺失时会主动调用
;; package-refresh-contents，等于把网络请求塞回启动路径上（实测能卡 27 秒）。
;; 装包统一走 M-x my/bootstrap-packages。

;;; Code:

;; 依赖没装好就整段跳过：不联网、不报错。
(when (bound-and-true-p my/packages-ready)

  (use-package vertico
    :custom
    (vertico-cycle t)                 ; 到底之后回到顶部
    :init
    (vertico-mode 1))

  (use-package orderless
    :custom
    (completion-styles '(orderless basic))
    (completion-category-overrides '((file (styles basic partial-completion))))
    :init
    (setq completion-category-defaults nil))

  (use-package marginalia
    :init
    (marginalia-mode 1))

  (use-package consult
    :bind (("C-x b" . consult-buffer)
           ("C-s"   . consult-line)     ; 带预览的搜索，取代 isearch
           ("M-y"   . consult-yank-pop)
           ("M-g g" . consult-goto-line)
           ("C-c i" . consult-imenu))
    :custom
    (consult-narrow-key "<"))

  ;; eglot 的符号列表接到 consult：按名字找函数/结构体/方法，列表里有位置预览。
  ;; 只在 LSP 接管的 buffer 里有效，所以绑在 eglot-mode-map 上而不是全局。
  (use-package consult-eglot
    :after eglot
    :bind (:map eglot-mode-map
                ("C-c C-e" . consult-eglot-symbols)))

;;; ---------------------------------------------------------------------------
;;; buffer 内补全（corfu + cape）
;;;
;;; eglot 只管"用哪个后端"，不管"候选怎么显示"。没有 corfu 的时候，
;;; rust-analyzer / zls 的补全只能靠 C-M-i 弹一个原始的 *Completions* 列表，
;;; 等于 LSP 只用了跳转和诊断，补全那半截是空的。
;;;
;;; cape 是"多来源"：把 dabbrev（同 buffer 里出现过的词）和文件路径也接进
;;; 同一个 capf 列表，这样没有 LSP 的 buffer 里也有东西可补。
;;; ---------------------------------------------------------------------------

  (use-package corfu
    :custom
    (corfu-cycle t)                   ; 到底之后回到顶部
    (corfu-auto t)                    ; 边打边弹，不用手动触发
    (corfu-auto-delay 0.15)
    (corfu-auto-prefix 2)             ; 打满 2 个字符才开始补
    (corfu-quit-no-match 'separator)  ; 没有匹配时不当场关掉
    :init
    (global-corfu-mode 1))

  (use-package cape
    :init
    ;; 没有 LSP 的 buffer（纯文本文档之类）也有东西可补
    (add-hook 'completion-at-point-functions #'cape-dabbrev)
    (add-hook 'completion-at-point-functions #'cape-file)
    :config
    ;; eglot 往 buffer 里加的是**局部**的 capf，局部值会整个盖掉全局值，
    ;; 上面那两条全局注册在 eglot 管着的 buffer 里等于没加。
    ;; 所以接管之后再补一次局部的：depth 10 = 排在 eglot 之后当兜底。
    (add-hook 'eglot-managed-mode-hook
              (lambda ()
                (add-hook 'completion-at-point-functions #'cape-dabbrev 10 t)
                (add-hook 'completion-at-point-functions #'cape-file 10 t))))

;;; ---------------------------------------------------------------------------
;;; embark：对候选本身做操作
;;;
;;; 补全列表里选中的东西，除了"插进去"还能干别的：改文件名、kill 一个 buffer、
;;; 把路径插到别处。embark 就是给候选挂一个动词菜单。
;;; embark-consult 让它和 consult 的预览配合起来。
;;; ---------------------------------------------------------------------------

  (use-package embark
    :bind (("C-." . embark-act)
           ("C-;" . embark-dwim))
    :init
    (setq prefix-help-command #'embark-prefix-help-command))

  (use-package embark-consult
    :after (embark consult)
    :hook (embark-collect-mode . consult-preview-at-point-mode)))

;; 下面几条是 Emacs 自带的，不依赖第三方包，所以放在判断之外。

;; which-key 从 Emacs 30 起内置，不用装包。按键前缀停半秒就把后续按键列出来，
;; 提示用；新绑的 C-c g（lazygit）、C-./C-; 这些也能被它提示到。
(when (fboundp 'which-key-mode)
  (which-key-mode 1)
  (setq which-key-idle-delay 0.5))

;; 记住 minibuffer 历史，重启后还能翻到之前输入过的内容
(savehist-mode 1)
(setq history-length 500)

;; 最近访问的文件，consult-buffer 和 M-x recentf 都会用到
;; 关掉启动时的自动清理：它会逐个 `file-exists-p'，一旦列表里有网络路径
;; （\\server\share\...）或已拔掉的盘，每次 stat 都可能卡很久——这是
;; 「启动莫名其妙要几十秒」的常见来源。要清理就手动 M-x recentf-cleanup。
(setq recentf-auto-cleanup 'never)
(recentf-mode 1)
(setq recentf-max-saved-items 200)

;; 在 minibuffer 里还能再开一个 minibuffer（consult 的部分命令需要）
(setq enable-recursive-minibuffers t)

;; C-s 默认变成了 consult-line。想退回原来的 isearch：
;;   (keymap-global-set "C-s" #'isearch-forward)

(provide 'my-completion)
;;; my-completion.el ends here
