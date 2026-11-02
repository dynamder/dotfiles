;;; rose-pine-common.el --- Rosé Pine 三个变体的共享实现 -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; 三个变体（main / moon / dawn）共用这里的调色板和脸面表，避免把同一份
;; 两百行的脸面清单抄三遍。
;;
;; 色值取自官方色板，未经改动：
;;   https://rosepinetheme.com/palette/
;;   https://github.com/rose-pine/rose-pine-palette/blob/main/dist/css/rose-pine.css
;;
;; 官方给的语义（见 rose-pine-palette 的 README）：
;;
;;   base            主背景
;;   surface         次级背景（输入框、面板）
;;   overlay         再上一层
;;   muted           低对比前景 —— 注释、被忽略的东西
;;   subtle          中对比前景 —— 标点、运算符、未选中的项
;;   text            高对比前景 —— 正文
;;   highlight-low   光标行
;;   highlight-med   选区
;;   highlight-high  光标背景、边框
;;
;;   love  红   内建、错误、git delete
;;   gold  黄   字符串、警告
;;   rose  青   布尔、git change
;;   pine  绿   函数
;;   foam  蓝   键名、信息
;;   iris  紫   参数、链接、提示
;;
;; 与社区那个 emacs 移植（thongpv87/rose-pine-emacs）的关键差别：那个把
;; outline-N 和 bold 全部设成 surface（#555169），走的是 nano-emacs 的极低
;; 对比路线，标题和加粗会灰成一片。这里按官方"高对比前景"的定位处理，
;; 因为写文档时标题必须看得清。

;;; Code:

(defconst rose-pine-palettes
  '((main . ((base           . "#191724")
             (surface        . "#1f1d2e")
             (overlay        . "#26233a")
             (muted          . "#6e6a86")
             (subtle         . "#908caa")
             (text           . "#e0def4")
             (love           . "#eb6f92")
             (gold           . "#f6c177")
             (rose           . "#ebbcba")
             (pine           . "#31748f")
             (foam           . "#9ccfd8")
             (iris           . "#c4a7e7")
             (highlight-low  . "#21202e")
             (highlight-med  . "#403d52")
             (highlight-high . "#524f67")))
    (moon . ((base           . "#232136")
             (surface        . "#2a273f")
             (overlay        . "#393552")
             (muted          . "#6e6a86")
             (subtle         . "#908caa")
             (text           . "#e0def4")
             (love           . "#eb6f92")
             (gold           . "#f6c177")
             (rose           . "#ea9a97")
             (pine           . "#3e8fb0")
             (foam           . "#9ccfd8")
             (iris           . "#c4a7e7")
             (highlight-low  . "#2a283e")
             (highlight-med  . "#44415a")
             (highlight-high . "#56526e")))
    (dawn . ((base           . "#faf4ed")
             (surface        . "#fffaf3")
             (overlay        . "#f2e9e1")
             (muted          . "#9893a5")
             (subtle         . "#797593")
             (text           . "#575279")
             (love           . "#b4637a")
             (gold           . "#ea9d34")
             (rose           . "#d7827e")
             (pine           . "#286983")
             (foam           . "#56949f")
             (iris           . "#907aa9")
             (highlight-low  . "#f4ede8")
             (highlight-med  . "#dfdad9")
             (highlight-high . "#cecacd"))))
  "官方色板的三个变体，值即 hex 字符串。")

;;; ---------------------------------------------------------------------------
;;; 脸面清单
;;
;; 属性值里出现的符号（base / text / iris ...）在定义主题时会被替换成色值，
;; 不出现的就原样保留（t、bold、1.3 这种）。
;; ---------------------------------------------------------------------------

(defconst rose-pine--core-faces
  '((default                            (:background base :foreground text))
    (cursor                             (:background text))
    (fringe                             (:background base :foreground muted))
    (internal-border                    (:background base))

    ;; --- 选区与高亮 ---
    (region                             (:background highlight-med :foreground text))
    (secondary-selection                (:background overlay))
    (highlight                          (:background highlight-med))
    (hl-line                            (:background highlight-low))
    (trailing-whitespace                (:foreground love :underline t))
    (show-paren-match                   (:foreground rose :weight bold))
    (show-paren-match-expression        (:background highlight-med))
    (show-paren-mismatch                (:background love :foreground text))

    ;; --- 语义色 ---
    (error                              (:foreground love :weight bold))
    (warning                            (:foreground gold :weight bold))
    (success                            (:foreground pine :weight bold))
    (shadow                             (:foreground muted))
    (escape-glyph                       (:foreground gold))
    (homoglyph                          (:foreground gold))
    (nobreak-space                      (:foreground subtle))

    ;; --- 链接与按钮 ---
    (link                               (:foreground iris :underline t))
    (link-visited                       (:foreground rose :underline t))
    (button                             (:foreground iris :underline t))
    (minibuffer-prompt                  (:foreground iris :weight bold))

    ;; --- modeline / 框架 ---
    (mode-line                          (:background surface :foreground text))
    (mode-line-inactive                 (:background base :foreground muted))
    (mode-line-emphasis                 (:foreground rose :weight bold))
    (mode-line-buffer-id                (:foreground iris :weight bold))
    (mode-line-highlight                (:background highlight-high))
    (header-line                        (:background surface :foreground subtle))
    (tab-bar                            (:background base :foreground muted))
    (tab-bar-tab                        (:background surface :foreground text :weight bold))
    (tab-bar-tab-inactive               (:background base :foreground muted))
    (tooltip                            (:background overlay :foreground text))
    (vertical-border                    (:foreground highlight-high))
    (window-divider                     (:foreground surface))
    (window-divider-first-pixel         (:foreground overlay))
    (window-divider-last-pixel          (:foreground overlay))
    (scroll-bar                         (:background surface))

    ;; --- 搜索 ---
    (isearch                            (:background gold :foreground base :weight bold))
    (isearch-fail                       (:background love :foreground base :weight bold))
    (lazy-highlight                     (:background highlight-high :foreground text))
    (match                              (:background highlight-high :foreground love :weight bold))
    (completions-common-part            (:foreground foam))
    (completions-first-difference       (:foreground love :weight bold))

    ;; --- 行号 ---
    (line-number                        (:background base :foreground muted))
    (line-number-current-line           (:background highlight-low :foreground rose :weight bold))
    (line-number-major-tick             (:foreground gold))
    (line-number-minor-tick             (:foreground subtle))

    ;; --- 语法 ---
    (font-lock-comment-face             (:foreground muted :slant italic))
    (font-lock-comment-delimiter-face   (:foreground muted))
    (font-lock-doc-face                 (:foreground subtle :slant italic))
    (font-lock-string-face              (:foreground gold))
    (font-lock-keyword-face             (:foreground iris))
    (font-lock-builtin-face             (:foreground love))
    (font-lock-function-name-face       (:foreground pine))
    (font-lock-function-call-face       (:foreground pine))
    (font-lock-variable-name-face       (:foreground text))
    (font-lock-variable-use-face        (:foreground text))
    (font-lock-type-face                (:foreground foam))
    (font-lock-constant-face            (:foreground rose))
    (font-lock-number-face              (:foreground rose))
    (font-lock-property-name-face       (:foreground foam))
    (font-lock-property-use-face        (:foreground foam))
    (font-lock-operator-face            (:foreground subtle))
    (font-lock-bracket-face             (:foreground subtle))
    (font-lock-delimiter-face           (:foreground subtle))
    (font-lock-escape-face              (:foreground love))
    (font-lock-negation-char-face       (:foreground love))
    (font-lock-preprocessor-face        (:foreground rose))
    (font-lock-warning-face             (:foreground gold :weight bold)))

  "启动时就存在的脸面。outline / hl-line 要等各自的库加载，放在下面那组。")

(defconst rose-pine--markdown-faces
  '((markdown-header-face-1            (:foreground iris :weight bold :height 1.25))
    (markdown-header-face-2            (:foreground foam :weight bold :height 1.15))
    (markdown-header-face-3            (:foreground rose :weight bold :height 1.08))
    (markdown-header-face-4            (:foreground gold :weight bold))
    (markdown-header-face-5            (:foreground pine :weight bold))
    (markdown-header-face-6            (:foreground love :weight bold))
    (markdown-bold-face                (:foreground text :weight bold))
    (markdown-italic-face              (:foreground rose :slant italic))
    (markdown-inline-code-face         (:foreground foam :background overlay))
    (markdown-code-face                (:background highlight-low))
    (markdown-pre-face                 (:foreground foam :background highlight-low))
    (markdown-language-keyword-face    (:foreground pine :slant italic))
    (markdown-language-info-face       (:foreground muted))
    (markdown-link-face                (:foreground iris :underline t))
    (markdown-url-face                 (:foreground foam :underline t))
    (markdown-plain-url-face           (:foreground foam :underline t))
    (markdown-reference-face           (:foreground iris))
    (markdown-footnote-face            (:foreground iris))
    (markdown-markup-face              (:foreground muted))
    (markdown-list-face                (:foreground love :weight bold))
    (markdown-blockquote-face          (:foreground subtle :slant italic))
    (markdown-table-face               (:foreground subtle))
    (markdown-hr-face                  (:foreground muted))
    (markdown-html-tag-name-face       (:foreground foam))
    (markdown-html-attr-name-face      (:foreground gold))
    (markdown-html-attr-value-face     (:foreground rose))
    (markdown-missing-link-face        (:foreground love :weight bold))
    (markdown-error-face               (:foreground love :underline t))
    (markdown-comment-face             (:foreground muted :slant italic)))

  "markdown-mode 加载后才存在的脸面。")

(defconst rose-pine--package-faces
  '((outline
     (outline-1                          (:foreground iris :weight bold))
     (outline-2                          (:foreground foam :weight bold))
     (outline-3                          (:foreground rose :weight bold))
     (outline-4                          (:foreground gold :weight bold))
     (outline-5                          (:foreground pine :weight bold))
     (outline-6                          (:foreground love :weight bold))
     (outline-7                          (:foreground iris))
     (outline-8                          (:foreground foam)))
    (hl-line
     (hl-line                             (:background highlight-low)))
    (diff-mode
     (diff-header                     (:foreground subtle))
     (diff-file-header                (:foreground text :weight bold))
     (diff-hunk-header                (:foreground iris))
     (diff-added                      (:foreground pine))
     (diff-removed                    (:foreground love))
     (diff-changed                    (:foreground gold))
     (diff-indicator-added            (:foreground pine))
     (diff-indicator-removed          (:foreground love))
     (diff-indicator-changed          (:foreground gold))
     (diff-refine-added               (:background pine :foreground base))
     (diff-refine-removed             (:background love :foreground base))
     (diff-refine-changed             (:background gold :foreground base)))
    (dired
     (dired-directory                 (:foreground iris :weight bold))
     (dired-header                    (:foreground foam :weight bold))
     (dired-mark                      (:foreground gold))
     (dired-marked                    (:foreground rose :weight bold))
     (dired-flagged                   (:foreground love :weight bold))
     (dired-symlink                   (:foreground foam))
     (dired-warning                   (:foreground gold))
     (dired-ignored                   (:foreground muted)))
    (flymake
     (flymake-error                   (:underline (:style wave :color love)))
     (flymake-warning                 (:underline (:style wave :color gold)))
     (flymake-note                    (:underline (:style wave :color foam))))
    (whitespace
     (whitespace-space                (:foreground highlight-high))
     (whitespace-hspace               (:foreground highlight-high))
     (whitespace-tab                  (:foreground highlight-high))
     (whitespace-newline              (:foreground highlight-high))
     (whitespace-trailing             (:background love :foreground love))
     (whitespace-line                 (:background highlight-low))
     (whitespace-big-indent           (:background love :foreground base))
     (whitespace-space-before-tab     (:background gold :foreground base))
     (whitespace-space-after-tab      (:background gold :foreground base)))
    (vertico
     (vertico-current                 (:background highlight-med :foreground text)))
    (marginalia
     (marginalia-documentation        (:foreground muted))
     (marginalia-file-name            (:foreground subtle))
     (marginalia-size                 (:foreground foam))
     (marginalia-mode                 (:foreground rose))
     (marginalia-date                 (:foreground foam))
     (marginalia-number               (:foreground rose))
     (marginalia-type                 (:foreground pine))
     (marginalia-key                  (:foreground iris)))
    (consult
     (consult-preview-match           (:background highlight-high :foreground love))
     (consult-preview-line            (:background highlight-low))
     (consult-line-number             (:foreground muted))
     (consult-line-number-prefix      (:foreground muted))
     (consult-file                    (:foreground text))
     (consult-heading                 (:foreground iris))
     (consult-key                     (:foreground rose))
     (consult-separator               (:foreground overlay)))
    (which-key
     (which-key-key-face              (:foreground iris :weight bold))
     (which-key-separator-face        (:foreground muted))
     (which-key-group-description-face (:foreground rose))
     (which-key-command-description-face (:foreground text)))
    (doom-modeline
     (doom-modeline-buffer-path       (:foreground text))
     (doom-modeline-buffer-file       (:foreground text :weight bold))
     (doom-modeline-buffer-modified   (:foreground love :weight bold))
     (doom-modeline-buffer-major-mode (:foreground pine))
     (doom-modeline-buffer-minor-mode (:foreground muted))
     (doom-modeline-project-dir       (:foreground iris))
     (doom-modeline-info              (:foreground foam))
     (doom-modeline-warning           (:foreground gold))
     (doom-modeline-error             (:foreground love))
     (doom-modeline-panel             (:background highlight-med :foreground text))))
  "只在对应包加载后才存在的脸面：(库名 脸面清单...)。")

;;; ---------------------------------------------------------------------------
;;; 实现
;;; ---------------------------------------------------------------------------

(defun rose-pine--resolve (palette value)
  "把 VALUE 里的调色板符号递归替换成 PALETTE 中的色值。

必须递归：`:underline (:style wave :color love)` 这种属性的值是**嵌套的
plist**，只替换顶层的话 `love` 会原样留下，Emacs 就会报
`Invalid face underline: :style, wave, :color, love`。"
  (cond
   ((and (symbolp value) (assq value palette))
    (cdr (assq value palette)))
   ((consp value)
    (mapcar (lambda (v) (rose-pine--resolve palette v)) value))
   (t value)))

(defun rose-pine--apply (theme palette specs)
  "给 THEME 应用 SPECS。

两件事值得说明：

1. 未定义的脸面直接跳过。给不存在的脸面设色会报 `Invalid face'，
   而 markdown / outline 这些脸面要等各自的库加载后才存在。
2. `custom--inhibit-theme-enable' 在 load-theme 之外默认是 `apply-only-user'，
   意思是「只记录不生效」。延迟应用发生在主题已经启用之后，如果不把它
   绑成 nil，颜色只会记进主题设置里，屏幕上一点变化都没有。"
  (let ((custom--inhibit-theme-enable
         (unless (custom-theme-enabled-p theme) t)))
    (dolist (spec specs)
      (when (facep (car spec))
        (custom-theme-set-faces
         theme
         (list (car spec)
               (list (list t (rose-pine--resolve palette (nth 1 spec))))))))))

(defun rose-pine--apply-deferred (theme palette)
  "登记那些要等包加载后才存在的脸面。"
  (dolist (group rose-pine--package-faces)
    (let ((library (car group)))
      (with-eval-after-load library
        (rose-pine--apply theme palette (cdr group)))))
  (with-eval-after-load 'markdown-mode
    (rose-pine--apply theme palette rose-pine--markdown-faces)))

(defun rose-pine--define (theme variant)
  "把 VARIANT 变体定义成主题 THEME。"
  (let ((palette (alist-get variant rose-pine-palettes)))
    (unless palette
      (error "Rosé Pine: unknown variant %s" variant))
    (rose-pine--apply theme palette rose-pine--core-faces)
    (rose-pine--apply-deferred theme palette)))

(provide 'rose-pine-common)
;;; rose-pine-common.el ends here
