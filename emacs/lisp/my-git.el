;;; my-git.el --- 用 lazygit 当 git 界面 -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; 不装 magit。magit 会带进 transient / with-editor / git-commit 一串依赖，
;; 而你本来就用 lazygit——它已经在 PATH 上，交互模型你也熟。
;; Emacs 这边只需要当个宿主：开一个终端 buffer，把它放在项目根目录里跑。
;;
;; 为什么用内置的 `term' 而不是 vterm / eat：
;;
;;   vterm  要编译（cmake + libvterm），这台机器既没有 gcc 也没有 cmake；
;;   eat    不在 MELPA 里，从 GNU ELPA 拿是否可用不确定；
;;   term   内置、零依赖，lazygit 这种 TUI 跑得动。
;;
;; 哪天真的装了 eat，把 `my/lazygit' 里 `(term my/lazygit-program)' 那一行
;; 换成 eat 的启动函数即可，其余逻辑不用动。
;;
;; 一个刻意的取舍：**不**用 `lazygit -p <path>' 显式传路径。`term' 会把它
;; 收到的字符串按空格切开当程序名和参数，路径里一旦有空格就碎掉（Windows 的
;; `C:/Users/atomt/...' 眼下没空格，但这是个不该赌的前提）。所以改为绑定
;; `default-directory'，让 lazygit 自己用 cwd。

;;; Code:

(defvar my/lazygit-program "lazygit"
  "lazygit 可执行文件。改了要重求值这个文件。")

(defun my/project-root ()
  "当前 buffer 所在项目的根目录；不在项目里就用 `default-directory'。
`project-current' 对 git 仓库走 VC 后端，所以只要有 .git 就认得出来。"
  (or (ignore-errors
        (when-let* ((proj (project-current)))
          (file-name-as-directory (expand-file-name (project-root proj)))))
      (file-name-as-directory (expand-file-name default-directory))))

(defun my/lazygit--buffer-name (dir)
  "按 DIR 生成 lazygit buffer 的名字。"
  (format "*lazygit: %s*" (abbreviate-file-name (directory-file-name dir))))

(defun my/lazygit ()
  "在项目根目录打开 lazygit。
已经开着同一个项目的 lazygit 时直接切过去，不重开。"
  (interactive)
  (unless (executable-find my/lazygit-program)
    (user-error "找不到 %s，先确认它在 PATH 上" my/lazygit-program))
  (let* ((dir (my/project-root))
         (name (my/lazygit--buffer-name dir))
         (existing (get-buffer name)))
    (if (and existing (comint-check-proc existing))
        (pop-to-buffer existing)
      ;; `term' 用调用时当前 buffer 的 `default-directory'，所以在这里 bind。
      (let ((default-directory dir))
        (term my/lazygit-program)
        (rename-buffer name t)))))

;; C-c + 字母 是留给用户的键位区，不和包抢。
(keymap-global-set "C-c g" #'my/lazygit)

(provide 'my-git)
;;; my-git.el ends here
