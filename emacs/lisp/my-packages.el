;;; my-packages.el --- 包源、代理、失败切换与依赖安装 -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; 结论先写在前面，因为这几条都是实测出来的：
;;
;; 1. **Emacs 进程内没法给网络操作设上限。**
;;    在 Windows + 本地代理下，`url-retrieve' 会在返回之前就卡死：异步回调
;;    进不去，`accept-process-output' 的截止时间没机会跑，`C-g' 也按不动。
;;    所以超时参数是安慰剂，唯一有效的做法是「放到子进程里，到点 kill」。
;;
;; 2. **启动路径上什么都不做。**
;;    不联网、不 spawn 进程。代理检测也是惰性的，只在真正要下载时做。
;;
;; 3. **子进程的退出码不可靠**（实测 `kill-emacs 7` 回来是 0），
;;    标准输出在 `require url' 之后也会丢。所以结论靠临时文件回传。
;;
;; 4. 装包是显式命令（`my/bootstrap-packages`），不是启动的一部分。
;;    永远不要用 `use-package' 的 :ensure——它在包缺失时会主动刷新索引。

;;; Code:

(require 'package)
(require 'gnutls)

;;; ---------------------------------------------------------------------------
;;; 零、CA 证书包：Emacs 在 Windows 上默认找不到它
;;; ---------------------------------------------------------------------------

(defvar my/ca-bundles
  '("C:/Program Files/Git/mingw64/etc/ssl/certs/ca-bundle.crt"
    "C:/Program Files/Git/usr/ssl/certs/ca-bundle.crt"
    "C:/Program Files/Git/mingw64/ssl/certs/ca-bundle.crt"
    "C:/Program Files/Git/mingw64/libexec/ssl/certs/ca-bundle.crt"
    "C:/ProgramData/chocolatey/lib/git.install/tools/mingw64/etc/ssl/certs/ca-bundle.crt")
  "候选 CA 证书包。只在 Emacs 自带的那批路径全都不存在时才启用。

Windows 上 `gnutls-trustfiles' 默认是一串 `/etc/ssl/...' 的 Unix 路径，
一个都不存在，于是所有 HTTPS 握手都以 connection-failed 结束——表现为
「所有源都 fail」，看起来像网络问题，其实是证书库没配上。")

(defun my/ensure-ca-bundle ()
  "如果 Emacs 默认的 CA 路径都不存在，就换成本机真实存在的那个。
返回最终使用的文件，找不到则 nil。"
  (if (seq-some #'file-exists-p gnutls-trustfiles)
      (seq-find #'file-exists-p gnutls-trustfiles)
    (let ((found (seq-find #'file-exists-p (mapcar #'expand-file-name my/ca-bundles))))
      (when found (setq gnutls-trustfiles (list found)))
      found)))

(my/ensure-ca-bundle)

;;; ---------------------------------------------------------------------------
;;; 一、包源
;;; ---------------------------------------------------------------------------

(defvar my/archive-sources
  '((gnu    "https://elpa.gnu.org/packages/"
            "https://mirrors.ustc.edu.cn/elpa/gnu/"
            "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
    (nongnu "https://elpa.nongnu.org/nongnu/"
            "https://mirrors.ustc.edu.cn/elpa/nongnu/"
            "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
    (melpa  "https://melpa.org/packages/"
            "https://mirrors.ustc.edu.cn/elpa/melpa/"
            "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/"))
  "归档名 -> 候选地址，前面的优先。
官方排第一，镜像只在官方不通时才用。想固定用官方，把每项的镜像行删掉。")

(defconst my/packages
  '(vertico orderless marginalia consult     ; 补全与搜索
    corfu cape                               ; buffer 内补全 / 多来源 capf
    embark embark-consult                    ; 对候选本身做操作
    nerd-icons doom-modeline                 ; modeline
    markdown-mode edit-indirect              ; markdown 本体
    mixed-pitch olivetti valign              ; 写作排版
    apheleia consult-eglot zig-ts-mode)      ; 代码：格式化 / LSP 符号 / zig
  "配置依赖的第三方包。增删依赖时同步维护。

`which-key' 不在此列——Emacs 30 起它内置，不需要装。
lazygit 也不在这里：它是外部程序，见 lisp/my-git.el。")

;;; ---------------------------------------------------------------------------
;;; 二、代理：惰性检测，端口不写死
;;; ---------------------------------------------------------------------------

(defvar my/use-proxy nil
  "非 nil 时使用系统代理。默认直连。

为什么默认关：实测这台机器上 Emacs 走本地代理会得到 HTTP 400
（代理不接受 Emacs 发的请求），而直连配合正确的 CA 证书包是 200。
要用代理就把它设 t，或用 `my/proxy-override' 指定。")

(defvar my/proxy-override nil
  "手动指定 \"host:port\"，优先于系统设置。")

(defvar my/proxy nil
  "当前生效的代理；nil 表示直连。由 `my/apply-proxy' 刷新。")

(defun my/normalize-proxy (value)
  "把各种代理写法统一成 \"host:port\"。
支持 `127.0.0.1:7897'、`http://127.0.0.1:7897/'、
`http=1.2.3.4:7897;https=1.2.3.4:7897'。"
  (let ((v (and (stringp value) (string-trim value))))
    (when (and v (not (string-empty-p v)))
      (when (string-match "\\(?:https?=\\)\\([^;]+\\)" v)
        (setq v (match-string 1 v)))
      (setq v (replace-regexp-in-string "\\`[a-zA-Z]+://" "" v))
      (setq v (car (split-string v "/")))
      (unless (string-empty-p v) v))))

(defun my/windows-system-proxy ()
  "读 Windows 系统代理（ProxyEnable=1 时返回 \"host:port\"）。"
  (when (eq system-type 'windows-nt)
    (let* ((reg (or (executable-find "reg") "reg.exe"))
           (res (my/run-bounded
                 reg
                 (list "query"
                       "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings")
                 5))
           (out (cdr res)))
      (when (and (integerp (car res))
                 (string-match-p "ProxyEnable[ \t]+REG_DWORD[ \t]+0x1" out)
                 (string-match "ProxyServer[ \t]+REG_SZ[ \t]+\\([^ \t\r\n]+\\)" out))
        (my/normalize-proxy (match-string 1 out))))))

(defun my/apply-proxy ()
  "重新读系统代理并写入 `url-proxy-services'。返回 \"host:port\" 或 nil。

这是**主动调用**的函数，不在加载时执行——启动路径上不 spawn 进程。
代理客户端换端口后，下次 bootstrap 会自动重读，也可以 M-x 手动调。"
  (interactive)
  (setq my/proxy (when my/use-proxy
                   (or (my/normalize-proxy my/proxy-override)
                       (my/windows-system-proxy))))
  (setq url-proxy-services
        (when my/proxy
          `(("http" . ,my/proxy)
            ("https" . ,my/proxy)
            ("no_proxy" . "^\\(localhost\\|127\\.0\\.0\\.1\\)"))))
  (when (called-interactively-p 'any)
    (message "Proxy: %s" (or my/proxy "direct")))
  my/proxy)

;;; ---------------------------------------------------------------------------
;;; 三、子进程：带硬超时地跑外部程序
;;; ---------------------------------------------------------------------------

(defun my/run-bounded (program args timeout)
  "运行 PROGRAM ARGS，最多等 TIMEOUT 秒，超时就杀掉。

返回 (STATUS . OUTPUT)。STATUS 是退出码，或符号 `timeout' / `missing'。

两个细节都是踩过的坑：
  * 退出码靠 sentinel 拿，不靠轮询 `process-live-p'；
  * 进程退出后再排空一次管道，否则拿到空字符串。"
  (let ((out (generate-new-buffer " *my-proc*"))
        (done nil)
        (code nil))
    (unwind-protect
        (let ((proc (condition-case nil
                        (make-process :name "my-proc" :buffer out
                                      :command (cons program args)
                                      :connection-type 'pipe :noquery t
                                      :sentinel
                                      (lambda (p _event)
                                        (unless (process-live-p p)
                                          (setq code (process-exit-status p))
                                          (setq done t))))
                      (error nil))))
          (cond
           ((null proc) (cons 'missing ""))
           (t
            (let ((deadline (+ (float-time) timeout)))
              (while (and (not done) (< (float-time) deadline))
                (accept-process-output proc 0.05)))
            (if (not done)
                (progn (delete-process proc) (cons 'timeout ""))
              (while (accept-process-output proc 0.02))
              (cons code (with-current-buffer out (buffer-string)))))))
      (kill-buffer out))))

(defun my/emacs-binary ()
  "当前 Emacs 的可执行文件路径，用来启动子进程。"
  (let* ((base (and invocation-directory
                    (expand-file-name (or invocation-name "emacs")
                                      invocation-directory)))
         (cands (if (eq system-type 'windows-nt)
                    (list (and base (concat base ".exe")) base)
                  (list base))))
    (or (seq-find (lambda (p) (and p (file-executable-p p))) cands)
        (executable-find "emacs"))))

(defun my/child-prelude ()
  "子进程需要的最小前置设置。

子进程是 `-Q' 启动的，不读任何配置，所以 CA 证书必须显式传进去，
否则它会用 Emacs 默认那堆不存在的 Unix 路径，握手再次失败。"
  (concat "(require 'gnutls)"
          (when (and gnutls-trustfiles (seq-some #'file-exists-p gnutls-trustfiles))
            (format "(setq gnutls-trustfiles '%S)" gnutls-trustfiles))))

(defun my/child-status (form timeout)
  "在无配置的子 Emacs 里执行 FORM，最多等 TIMEOUT 秒。
返回 `ok' / `fail' / `timeout'。子进程被 kill 时判 `timeout'。

FORM 写成临时 `.el' 文件、用 `-l' 加载，**不能**用 `--eval'：
实测 `(require 'url)' 之后放在 `--eval' 里的后续 form 会被静默丢弃，
子进程直接退出 0，什么都不写——这个坑很隐蔽。改用 `-l' 一切正常，
顺带也不用操心命令行引号转义。"
  (let ((script (condition-case nil (make-temp-file "my-child-" nil ".el") (error nil))))
    (if (null script)
        'fail
      (unwind-protect
          (progn
            (with-temp-file script (insert form))
            (pcase (car (my/run-bounded (my/emacs-binary)
                                        (list "-Q" "--batch" "-l" script)
                                        timeout))
              ('timeout 'timeout)
              (0 'ok)
              (_ 'fail)))
        (ignore-errors (delete-file script))))))

;;; ---------------------------------------------------------------------------
;;; 四、探测与下载（都在子进程里）
;;; ---------------------------------------------------------------------------

(defvar my/probe-timeout 5
  "单次探测最多等几秒。到点 kill 子进程。

值越小，遇到不通的源时切换越快；但太短会把「慢但能用」的源误判成 timeout。
官方源在国内经常整段不通，所以没取太大。")

(defvar my/download-timeout 60
  "单个归档下载最多等几秒。MELPA 的 archive-contents 有一两 MB。")

(defvar my/probe-before-download t
  "非 nil 时先探测再下载。探测只取几百字节的 .sig，比下载便宜得多。")

(defun my/probe-url (url)
  "探测 URL 是否可用，返回 `ok' / `fail' / `timeout'。

取 URL 下的 archive-contents.sig，要求 HTTP 200。
探测在子进程里跑，所以卡住只是被 kill，不会拖住 Emacs。"
  (let ((result (condition-case nil (make-temp-file "my-probe-" nil ".txt") (error nil))))
    (if (null result)
        'fail
      (unwind-protect
          (let ((form (format
                       (concat (my/child-prelude)
                               "(require 'url)"
                               "(let* ((url-proxy-services '%S)"
                               "       (r (condition-case nil"
                               "              (url-retrieve-synchronously %S t t %d)"
                               "            (error 'err))))"
                               "  (with-temp-file %S"
                               "    (insert (cond ((eq r 'timeout) \"timeout\")"
                               "                  ((and (bufferp r) (buffer-live-p r)"
                               "                        (with-current-buffer r"
                               "                          (memq url-http-response-status '(200 404))))"
                               "                   \"ok\")"
                               "                  (t \"fail\")))))")
                       url-proxy-services
                       (concat url "archive-contents.sig")
                       (max 2 (1- my/probe-timeout))
                       result)))
            (if (eq 'timeout (my/child-status form my/probe-timeout))
                'timeout
              (let ((verdict (condition-case nil
                                 (with-temp-buffer
                                   (insert-file-contents result)
                                   (string-trim (buffer-string)))
                               (error ""))))
                (cond ((string= verdict "ok") 'ok)
                      ((string= verdict "timeout") 'timeout)
                      (t 'fail)))))
        (ignore-errors (delete-file result))))))

(defun my/fetch-archive (name url)
  "在子进程里把归档 NAME 的索引从 URL 拉下来。
返回 `ok' / `fail' / `timeout'。

成功与否不看退出码（不可靠），看文件是否真的落盘。"
  (let* ((dir (expand-file-name (concat "archives/" (symbol-name name) "/")
                                package-user-dir))
         (file (expand-file-name "archive-contents" dir)))
    (ignore-errors (delete-file file))
    (let ((status (my/child-status
                   (format
                    (concat (my/child-prelude)
                            "(require 'package)"
                            "(setq package-user-dir %S"
                            "      package-archives '((%S . %S)))"
                            "(condition-case nil (package-refresh-contents) (error nil))")
                    package-user-dir (symbol-name name) url)
                   my/download-timeout)))
      (cond ((eq status 'timeout) 'timeout)
            ((file-exists-p file) 'ok)
            (t 'fail)))))

(defvar my/archive-cache-file
  (expand-file-name "my-archive-cache.el" user-emacs-directory)
  "记录上一次每个归档实际可用的地址。

作用很直接：官方不通时要先等一个探测超时才换镜像，每次启动都重来一遍
很烦。记住上次的结果，下次直接先试它。")

(defun my/load-archive-cache ()
  "读缓存，返回 ((归档 . 地址) ...)。读不到就返回 nil。"
  (when (file-exists-p my/archive-cache-file)
    (condition-case nil
        (with-temp-buffer
          (insert-file-contents my/archive-cache-file)
          (goto-char (point-min))
          (read (current-buffer)))
      (error nil))))

(defun my/save-archive-cache (chosen)
  "把本次选中的地址写盘，下次优先用。"
  (ignore-errors
    (with-temp-file my/archive-cache-file
      (insert ";; 由 my-packages.el 自动生成：上次可用的归档地址。\n")
      (prin1 chosen (current-buffer))
      (insert "\n"))))

;;; ---------------------------------------------------------------------------
;;; 五、失败切换刷新
;;; ---------------------------------------------------------------------------

(defun my/refresh-with-failover ()
  "逐个归档刷新索引，每个归档按候选地址依次切换。
返回非 nil 表示至少有一个归档成功。

上次成功的地址会被优先尝试（见 `my/archive-cache-file'），
所以「官方不通、每次都要等超时」只发生在第一次。"
  (my/apply-proxy)
  (message "Refreshing package index (proxy: %s)..." (or my/proxy "direct"))
  (let ((cache (my/load-archive-cache))
        chosen failed)
    (dolist (entry my/archive-sources)
      (let* ((name (car entry))
             (cached (cdr (assq name cache)))
             ;; 缓存的地址排到最前，其余保持原顺序
             (candidates (if (and cached (member cached (cdr entry)))
                             (cons cached (remove cached (cdr entry)))
                           (cdr entry)))
             (deferred nil)
             (url (catch 'found
                    (dolist (candidate candidates)
                      (message "  %s: probing %s" name candidate)
                      (let ((verdict (if my/probe-before-download
                                         (my/probe-url candidate)
                                       'ok)))
                        (pcase verdict
                          ('ok
                           (let ((r (my/fetch-archive name candidate)))
                             (cond ((eq r 'ok) (throw 'found candidate))
                                   ((eq r 'timeout) (message "    download timed out"))
                                   (t (message "    download failed")))))
                          ('timeout
                           (message "    %s timed out (probe), skipped" candidate))
                          (_
                           (message "    %s failed (probe), deferred" candidate)
                           (push candidate deferred)))))
                    ;; 快速失败的再试一次：探测可能不准，而下载本身有界。
                    (when deferred
                      (message "  %s: retrying without probe" name)
                      (dolist (candidate (nreverse deferred))
                        (when (eq (my/fetch-archive name candidate) 'ok)
                          (throw 'found candidate))))
                    nil)))
        (if url
            (progn
              (push (cons (symbol-name name) url) chosen)
              (message "  %s -> %s" name url))
          (push name failed)
          (message "  %s -> no candidate worked" name))))
    (when chosen
      (setq chosen (nreverse chosen))
      (setq package-archives chosen)
      (my/save-archive-cache chosen)
      (when (fboundp 'package-read-all-archive-contents)
        (package-read-all-archive-contents)))
    (when failed
      (message "Archives unavailable: %s" (mapconcat #'symbol-name failed " ")))
    (and chosen package-archive-contents)))

;;; ---------------------------------------------------------------------------
;;; 六、启动：只读本地索引
;;; ---------------------------------------------------------------------------

(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(when (null package-archive-contents)
  (message "No package index yet. Run M-x my/bootstrap-packages once, then restart Emacs."))

;; 依赖是否就绪 = 索引缓存存在 + 抽查一个包。
;;
;; 必须在这里算，**不能**在 init.el 里算：`package-initialize' 之前
;; `package-archive-contents' 还是空的，算出来永远是 nil——于是 init.el 后面
;; 所有 `(when my/packages-ready ...)' 的整段配置被静默跳过：vertico、
;; markdown-mode、apheleia、corfu 全都不加载，而 Emacs 照样能启动，只是变成
;; 一个几乎原生的编辑器。这个坑不报错，只看表面完全看不出来。
(setq my/packages-ready
      (and package-archive-contents
           (package-installed-p 'vertico)))

(require 'use-package)

(setq use-package-expand-minimally t
      use-package-compute-statistics t)

;; 不设 use-package-always-ensure，也**没有**任何 :ensure。

;;; ---------------------------------------------------------------------------
;;; 七、命令
;;; ---------------------------------------------------------------------------

(defun my/bootstrap-packages (&optional force)
  "安装 `my/packages' 里缺的包；索引已在本地时不再重新下载。

前缀参数（C-u）或 FORCE 非 nil 时强制刷新索引。
装完重启 Emacs。"
  (interactive "P")
  (unless (or noninteractive
              (y-or-n-p (format "Install %d packages? " (length my/packages))))
    (user-error "Cancelled"))
  (let ((ok (if (and (not force) package-archive-contents)
                (progn
                  (message "Using cached index (%d packages). C-u to force a refresh."
                           (length package-archive-contents))
                  'cached)
              (message "%d archives x %d candidates, probe %ss, download %ss"
                       (length my/archive-sources)
                       (apply #'max (mapcar (lambda (e) (length (cdr e)))
                                            my/archive-sources))
                       my/probe-timeout my/download-timeout)
              (my/refresh-with-failover))))
    ;; 走代理全挂就退回直连再试一轮：有些代理规则会拦掉特定域名。
    (when (and (null ok) my/proxy)
      (message "Failed through proxy %s; retrying direct..." my/proxy)
      (let ((my/use-proxy nil))
        (setq ok (my/refresh-with-failover)))
      (my/apply-proxy))
    (if (null ok)
        (message "No index could be fetched. Run M-x my/diagnose-network.")
      (dolist (pkg my/packages)
        (unless (package-installed-p pkg)
          (message "Installing %s..." pkg)
          (condition-case err
              (package-install pkg)
            (error (message "  %s failed: %s" pkg (error-message-string err))))))
      (let ((missing (seq-filter (lambda (p) (not (package-installed-p p))) my/packages)))
        (if missing
            (message "%d still missing: %s"
                     (length missing) (mapconcat #'symbol-name missing " "))
          (message "All dependencies installed. Restart Emacs."))))))

(defun my/diagnose-network ()
  "逐个候选地址探测，结果写进 `*my-network*'。

buffer 先显示再逐行填充，所以能立刻看到进度，不用等全部探完。"
  (interactive)
  (my/apply-proxy)
  (let ((buf (get-buffer-create "*my-network*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert (format "emacs      : %s\n" (or (my/emacs-binary) "not found")))
      (insert (format "proxy      : %s\n" (or my/proxy "direct")))
      (insert (format "probe secs : %s\n\n" my/probe-timeout)))
    (display-buffer buf)
    (dolist (entry my/archive-sources)
      (with-current-buffer buf (insert (format "%s:\n" (car entry))))
      (dolist (url (cdr entry))
        (message "probing %s ..." url)
        (let* ((t0 (float-time))
               (verdict (my/probe-url url))
               (secs (- (float-time) t0)))
          (with-current-buffer buf
            (insert (format "  %-56s %5.1fs  %s\n" url secs
                            (pcase verdict
                              ('ok "ok")
                              ('timeout "TIMEOUT (would hang Emacs)")
                              (_ "fail"))))
            (goto-char (point-max)))))
      (with-current-buffer buf (insert "\n")))
    (message "Done. See *my-network*.")))

(defun my/packages-status ()
  "报告代理、包源、索引与缺失依赖，排错用。"
  (interactive)
  (with-current-buffer (get-buffer-create "*my-packages*")
    (erase-buffer)
    (insert (format "user-emacs-directory: %s\n" user-emacs-directory))
    (insert (format "package-user-dir    : %s\n" package-user-dir))
    (insert (format "代理                : %s\n" (or my/proxy "直连（未检测）")))
    (insert (format "探测 / 下载超时     : %s 秒 / %s 秒\n"
                    my/probe-timeout my/download-timeout))
    (insert (format "\n索引：%s\n"
                    (if package-archive-contents
                        (format "%d 个包（已缓存）" (length package-archive-contents))
                      "空 —— 需要 M-x my/bootstrap-packages")))
    (insert "\n各归档当前地址：\n")
    (dolist (a package-archives)
      (insert (format "  %-8s %s\n" (car a) (cdr a))))
    (insert "\n依赖状态：\n")
    (dolist (pkg my/packages)
      (insert (format "  %-16s %s\n" pkg (if (package-installed-p pkg) "ok" "缺失"))))
    (emacs-lisp-mode)
    (display-buffer (current-buffer))))

(provide 'my-packages)
;;; my-packages.el ends here
