;;; huxi.el

;;; Commentary:

;;; Code:

(eval-when-compile
  (require 'cl))
(require 'help-mode)

;;;_. emacs21 compatible
(when (not (fboundp 'number-sequence))
  (defun number-sequence (from &optional to inc)
    (if (and to (<= from to))
        (cons from
              (number-sequence (+ from (or inc 1)) to inc)))))

(when (not (fboundp 'delete-dups))
  (defun delete-dups (list)
    "Destructively remove `equal' duplicates from LIST.
Store the result in LIST and return it.  LIST must be a proper list.
Of several `equal' occurrences of an element in LIST, the first
one is kept."
    (let ((tail list))
      (while tail
        (setcdr tail (delete (car tail) (cdr tail)))
        (setq tail (cdr tail))))
    list))

(defgroup huxi nil
  "huxi: emacs input method"
  :group 'lhuxi)

(defface huxi-string-face '((t (:underline t)))
  "Face to show current string"
  :group 'huxi)

(defface huxi-default-face
  '((((class color) (background dark))
     (:background "#333333" :foreground "#dcdccc"))
    (((class color) (background light))
     (:background "#f0f0f0" :foreground "#000000")))
  "Face for default foreground and background."
  :group 'huxi)

(defface huxi-comment-face
  '((t (:foreground "grey75")))
  "Face for comment"
  :group 'huxi)

(defface huxi-highlight-candidate-face
  '((t (:inherit font-lock-constant-face)))
  "Face for highlighted candidate."
  :group 'huxi)

(defface huxi-indicator-face
  '((((class color) (background dark))
     (:foreground "#9256B4" :bold t))
    (((class color) (background light))
     (:foreground "#9256B4" :bold t)))
  "Face for mode-line indicator when input-method is available."
  :group 'huxi)

;;;_. variable declare
(defvar huxi-package-list nil "所有正在使用的输入法")
(defvar huxi-current-package (make-vector 5 nil)
  "当前使用的输入法，一个 vector，有五个部分: package-name,
buffer-list,history, keymap, active-function.

buffer-list 中的每个 buffer 是这样的一个 Association List：
----------------------------------------
buffer         对应的 buffer
param          Parameter 部分的参数
file           对应的文件名
")
;; read from hx-table.txt
(defvar huxi-page-length 8 "每页显示的词条数目")
(defvar huxi-max-codes 3 "码长")
(defvar huxi-first-char (number-sequence ?a ?z) "Table 中所有首字母列表")
(defvar huxi-total-char (number-sequence ?a ?z) "所有可能的字符")
(defvar huxi-do-completion t "是否读入可能的补全")

(defvar huxi-current-key "" "已经输入的代码")
(defvar huxi-current-str "" "当前选择的词条")
(defvar huxi-current-temp "" "当前选择的词条前附加文字")
(defvar huxi-current-choices nil "所有可选的词条。

这个 list 的 CAR 是可选的词条，一般是一个字符串列表，但是也可以含有
list。但是这个 list 的第一个元素必须是将要插入的字符串。

CDR 部分是一个 Association list。通常含有这样的内容：
---------------------------
pos         上次选择的位置
completion  下一个可能的字母（如果 huxi-do-completion 为 t）
")
(defvar huxi-current-pos nil "当前选择的词条在 huxi-current-choices 中的位置")
(defvar huxi-guidance-str "" "显示可选词条的字符串")
(defvar huxi-translating nil "记录是否在转换状态")
(defvar huxi-overlay nil "显示当前选择词条的 overlay")
(defvar huxi-guidance-frame nil)
(defvar huxi-guidance-buf nil)

(defvar huxi-load-hook nil)
(defvar huxi-active-hook nil)

(defvar huxi-stop-function nil)
(defvar huxi-translate-function nil)
(defvar huxi-add-completion-function nil)
;; (defvar huxi-format-function 'huxi-format)
(defvar huxi-handle-function 'huxi-handle-string)

(defvar huxi-use-tooltip (not (or noninteractive
                                 emacs-basic-display
                                 (not (display-graphic-p))
                                 (not (fboundp 'x-show-tip)))))
(defvar huxi-tooltip-timeout 20)

(defvar huxi-buffer-name-format " *%s*"
  "buffer 的名字格式，%s 对应 package name")

(defvar huxi-quick-en t
  "默认打开快速英文切换功能")

(defvar huxi-quick-en-on nil 
  "是否已经进入快速英文状态")
(defvar huxi-temp-en nil)

(defvar huxi-show-first nil
  "显示第一项")

(defvar huxi-current-length 0
  "当前选择的词条字数")

(defvar huxi-mode-map
  (let ((map (make-sparse-keymap))
        (i ?\ ))
    (while (< i 127)
      (define-key map (char-to-string i) 'huxi-self-insert-command)
      (setq i (1+ i)))
    (setq i 128)
    (while (< i 256)
      (define-key map (vector i) 'huxi-self-insert-command)
      (setq i (1+ i)))
    (dolist (i (number-sequence ?0 ?9))
      (define-key map (char-to-string i) 'huxi-number-select))
    (dolist (i (number-sequence ?A ?Z))
      (define-key map (char-to-string i) 'huxi-en-toggle))
    ;; (define-key map " " 'huxi-select-current)
    (define-key map " " 'huxi-j1)
    (define-key map "`" 'huxi-j2)
    (global-set-key (kbd "`") 'huxi-j2)
    (define-key map [backspace] 'huxi-delete-last-char)
    (define-key map [delete] 'huxi-delete-last-char)
    (define-key map [escape] 'huxi-quit-clear)
    (define-key map "\C-z" 'huxi-delete-last-char)
    (define-key map (kbd "<left>") 'huxi-delete-last-char)
    (define-key map "\C-n" 'huxi-next-page)
    (define-key map "\C-p" 'huxi-previous-page)
    (define-key map "\C-m" 'huxi-quit-no-clear)
    (define-key map "\C-c" 'huxi-quit-clear)
    (define-key map "\t" 'huxi-table-show-completion)
    ;; (define-key map (kbd "C-,") 'huxi-punc1)
    ;; (define-key map (kbd "C-.") 'huxi-punc2)
    (define-key map (kbd "s-j") 'huxi-number-select-char-j1)
    (define-key map (kbd "s-d") 'huxi-number-select-char-j1)
    (define-key map (kbd "s-k") 'huxi-number-select-char-k2)
    (define-key map (kbd "s-l") 'huxi-number-select-char-l3)
    (define-key map (kbd "s-u") 'huxi-number-select-char-u4)
    (define-key map (kbd "s-i") 'huxi-number-select-char-i5)
    (define-key map (kbd "s-o") 'huxi-number-select-char-o6)
    map)
  "Keymap")

(defvar huxi-local-variable-list
  '(huxi-current-package
    huxi-max-codes
    huxi-page-length
    huxi-first-char
    huxi-total-char
    huxi-do-completion

    huxi-current-key
    huxi-current-str
    huxi-current-choices
    huxi-current-pos
    huxi-guidance-str
    huxi-translating
    huxi-overlay
    huxi-guidance-frame
    huxi-guidance-buf

    huxi-load-hook
    huxi-active-hook

    huxi-translate-function
    huxi-format-function
    huxi-handle-function
    huxi-add-completion-function
    huxi-stop-function

    input-method-function
    inactivate-current-input-method-function
    describe-current-input-method-function)
  "A list of buffer local variable")

(dolist (var huxi-local-variable-list)
  (make-variable-buffer-local var)
  (put var 'permanent-local t))

;;;_ , package contents
(defsubst huxi-package-name ()
  (aref huxi-current-package 0))

(defsubst huxi-buffer-list ()
  (aref huxi-current-package 1))

(defsubst huxi-history ()
  "保存输入过的词的选择，另一方面加快搜索。另外在这里来处理标点。
这个散列中的每个元素都有这样的格式：
  ((list WORDS) other-properties)
OTHER-PROPERTIES 是一些其它的属性，比如，上次的位置，用来输入标点等。"
  (aref huxi-current-package 2))

(defsubst huxi-mode-map ()
  (aref huxi-current-package 3))

(defsubst huxi-options ()
  (aref huxi-current-package 4))

(defsubst huxi-active-function ()
  (aref huxi-current-package 5))

(defsubst huxi-set-package-name (name)
  (aset huxi-current-package 0 name))

(defsubst huxi-set-buffer-list (list)
  (aset huxi-current-package 1 list))

(defsubst huxi-set-history (history)
  (aset huxi-current-package 2 history))

(defsubst huxi-set-mode-map (map)
  (aset huxi-current-package 3 map))

(defsubst huxi-set-options (options)
  (aset huxi-current-package 4 options))

(defsubst huxi-set-active-function (func)
  (aset huxi-current-package 5 func))

(defun huxi-get-option (option)
  (cdr (assoc option (huxi-options))))
(defun huxi-set-option (option flag)
  (let ((options (huxi-options))
        opt)
    (if (setq opt (assoc option options))
        (setcdr opt flag)
      (push (cons option flag) options)
      (huxi-set-options options))))

;;;_. read file functions
(defun huxi-load-file (file)
  (let ((bufname (format huxi-buffer-name-format (huxi-package-name)))
        buflist buf param files)
    (save-excursion
      (setq buf (huxi-read-file file bufname t))
      (setq param (cdr (assoc "param" buf)))
      (setq buflist (append buflist (list buf)))
      (when (setq files (assoc "other-files" param))
        (setq files (split-string (cadr files) ";"))
        (dolist (f files)
          (if (file-exists-p (expand-file-name f))
              (setq f (expand-file-name f))
            (setq f (locate-file f load-path)))
          (setq buflist (append buflist (list (huxi-read-file f bufname))))))
      buflist)))

(defun huxi-read-file (file name &optional read-param)
  (let (param region)
    (save-excursion
      (set-buffer (generate-new-buffer name))
      (insert-file-contents file)
      (if read-param
          (setq param (huxi-read-parameters)))
      (setq region (huxi-section-region "Table"))
      (narrow-to-region (car region) (cdr region))
      `(("buffer" . ,(current-buffer))
        ("param" . ,param)
        ("file" . ,file)))))

(defun huxi-section-region (sec)
  "得到一个部分的起点和终点位置，忽略最后的空行"
  (let ((reg (concat "^\\[" sec "\\]\n")))
    (save-excursion
      (if (not (re-search-forward reg nil t))
          (if (re-search-backward reg nil t)
              (forward-line 1)
            (error "文件类型错误！没有 %s 部分！" sec)))
      (cons (point) (progn
                      (if (re-search-forward "^\\[\\sw+\\]\n" nil t)
                          (forward-line -1)
                        (goto-char (point-max)))
                      (re-search-backward "[^  \t\n]" nil t)
                      (1+ (point)))))))

(defun huxi-read-parameters ()
  "得到 [Parameter] 部分的参数，以 assoc list 的形式返回"
  (let* ((r (huxi-section-region "Parameter"))
         param pair)
    (goto-char (car r))
    (while (< (point) (cdr r))
      (when (setq pair (huxi-line-content "=" t))
        (add-to-list 'param pair))
      (forward-line 1))
    param))

;;;_. common functions
(defsubst huxi-delete-region ()
  "Delete the text in the current translation region of E+."
  (when huxi-overlay
    (if (overlay-start huxi-overlay)
        (delete-region (overlay-start huxi-overlay)
                       (overlay-end huxi-overlay)))))

(when (not (fboundp 'emms-delete-if))
  (defun emms-delete-if (predicate seq)
    "Remove all items satisfying PREDICATE in SEQ.
This is a destructive function: it reuses the storage of SEQ
whenever possible."
    ;; remove from car
    (while (when (funcall predicate (car seq))
             (setq seq (cdr seq))))
    ;; remove from cdr
    (let ((ptr seq)
          (next (cdr seq)))
      (while next
        (when (funcall predicate (car next))
          (setcdr ptr (if (consp next)
                          (cdr next)
                        nil)))
        (setq ptr (cdr ptr))
        (setq next (cdr ptr))))
    seq))

(defun huxi-subseq (list from &optional to)
  (if (null to) (nthcdr from list)
    (butlast (nthcdr from list) (- (length list) to))))

(defun huxi-mod (x y)
  "like `mod', but when result is 0, return Y"
  (let ((base (mod x y)))
    (if (= base 0)
        y
      base)))

(defun huxi-string-emptyp (str)
  (not (string< "" str)))

(defun huxi-line-content (&optional seperaters omit-nulls)
  "用 SEPERATERS 分解当前行，所有参数传递给 split-string 函数"
  (let ((items   (split-string
                  (buffer-substring-no-properties
                   (line-beginning-position)
                   (line-end-position)) seperaters)))
    (if omit-nulls
        (emms-delete-if 'huxi-string-emptyp items)
      items)))

(defsubst huxi-delete-line ()
  (delete-region (line-beginning-position) (min (+ (line-end-position) 1)
                                                (point-max))))

(defsubst huxi-append-string (str)
  "append STR to huxi-current-str"
  (setq huxi-current-str (concat
                          huxi-current-temp
                          huxi-current-str str))
  (setq huxi-current-temp "")
  )

;;;_. code search
(defun huxi-get (code)
  (when (and (stringp code) (not (huxi-string-emptyp code)))
    (let ((history (gethash code (huxi-history)))
          pos words completions)
      (if (and (car history) (assoc "completions" (cdr history)))
          history
        (dolist (buf (huxi-buffer-list))
          (with-current-buffer (cdr (assoc "buffer" buf))
            (setq words (append words
                                (cdr
                                 (huxi-bisearch-word code
                                                     (point-min)
                                                     (point-max)))))
            (if huxi-do-completion
                (setq completions (huxi-completions code completions)))))
        (setq words (delete-dups words))
        (puthash code (list words
                            (cons "pos" (or (cdr (assoc "pos" (cdr history))) 1))
                            (cons "completions" completions))
                 (huxi-history))))))

(defun huxi-completions (code completions)
  (let ((maxln 200)
        (cnt 0)
        (len (length code))
        (reg (concat "^" (regexp-quote code))))
    (save-excursion
      (forward-line 1)
      ;; (setq hx (if (= 1 (length code))
      ;;              2
      ;;            1
      ;;            ))
      (while (and (looking-at reg)
                  (< cnt maxln))
        (add-to-list 'completions  (buffer-substring-no-properties
                                    (+ (point) len)
                                    (+ (point) len 1)) )
        (forward-line 1)
        (setq cnt (1+ cnt)))
      completions)))

(defun huxi-bisearch-word (code start end)
  (let ((mid (/ (+ start end) 2))
        ccode)
    (goto-char mid)
    (beginning-of-line)
    (setq ccode (huxi-code-at-point))
    ;;    (message "%d, %d, %d: %s" start mid end ccode)
    (if (string= ccode code)
        (huxi-line-content)
      (if (> mid start)
          (if (string< ccode code)
              (huxi-bisearch-word code mid end)
            (huxi-bisearch-word code start mid))))))

(defun huxi-code-at-point ()
  "Before calling this function, be sure that the point is at the
beginning of line"
  (save-excursion
    (if (re-search-forward "[ \t]" (line-end-position) t)
        (buffer-substring-no-properties (line-beginning-position) (1- (point)))
      (error "文件类型错误！%s 的第 %d 行没有词条！" (buffer-name) (line-number-at-pos)))))

;;;_. interface
(defun huxi-check-buffers ()
  "检查所有的 buffer 是否还存在，如果不存在，重新打开文件，如果文件不
存在，从 buffer-list 中删除这个 buffer"
  (let ((buflist (huxi-buffer-list))
        (bufname (huxi-package-name))
        buffer file)
    (dolist (buf buflist)
      (unless (buffer-live-p (cdr (setq buffer (assoc "buffer" buf))))
        (if (file-exists-p (setq file (cdr (assoc "file" buf))))
            (with-current-buffer (format "*%s*" (generate-new-buffer bufname))
              (insert-file-contents file)
              (setcdr buffer (current-buffer)))
          (message "%s for %s is not exists!" file bufname)
          (setq buflist (remove buf buflist)))))
    t))

(defun huxi-install-variable ()
  (let ((param (cdr (assoc "param" (car (huxi-buffer-list))))))
    (mapc (lambda (p)
            (let ((sym (intern-soft (concat "huxi-" (car p)))))
              (if sym
                  (set sym (mapconcat 'identity (cdr p) "=")))))
          param)
    (if (stringp huxi-page-length)
        (setq huxi-page-length (string-to-number huxi-page-length)))
    (if (stringp huxi-max-codes)
        (setq huxi-max-codes (string-to-number huxi-max-codes)))
    (setq huxi-first-char (append huxi-first-char nil)
          huxi-total-char (append huxi-total-char nil))))

;;;_ , huxi-use-package
(defun huxi-use-package (package-name &optional word-file active-func)
  (interactive)
  (mapc 'kill-local-variable huxi-local-variable-list)
  (mapc 'make-local-variable huxi-local-variable-list)
  (if (assoc package-name huxi-package-list)
      (setq huxi-current-package (cdr (assoc package-name
                                            huxi-package-list)))
    ;; make more room for extension
    (setq huxi-current-package (make-vector 9 nil)))
  (if (functionp active-func)
      (funcall active-func))
  (unless (and (huxi-package-name)
               (huxi-check-buffers))
    (if (and word-file
             (if (file-exists-p (expand-file-name word-file))
                 (setq word-file (expand-file-name word-file))
               (setq word-file (locate-file word-file load-path))))
        (progn
          (huxi-set-package-name package-name)
          (huxi-set-buffer-list (huxi-load-file word-file))
          (huxi-set-history (make-hash-table :test 'equal))
          (huxi-set-mode-map (let ((map (make-sparse-keymap)))
                              (set-keymap-parent map huxi-mode-map)
                              map))
          (add-to-list 'huxi-package-list (cons package-name huxi-current-package))
          (let ((param (cdr (assoc "param" (car (huxi-buffer-list))))))
            (if (assoc "lib" param)
                (load (cadr (assoc "lib" param)))))
          (run-hooks 'huxi-load-hook)
          (message nil))
      (error "没有这个文件: %s" word-file)))
  (huxi-install-variable)
  (setq input-method-function 'huxi-input-method)
  (setq inactivate-current-input-method-function 'huxi-inactivate)
  (setq describe-current-input-method-function 'huxi-help)
  (when (eq (selected-window) (minibuffer-window))
    (add-hook 'minibuffer-exit-hook 'huxi-exit-from-minibuffer))
  (run-hooks 'huxi-active-hook)
  (if (functionp (huxi-active-function))
      (funcall (huxi-active-function))))

(defun huxi-inactivate ()
  (interactive)
  (mapc 'kill-local-variable huxi-local-variable-list))

(defun huxi-help (&optional package)
  "Show input method docstring"
  (save-excursion
    (let ((map (huxi-mode-map))
          (elt (assoc (huxi-package-name) input-method-alist))
          reg desc docstr buf)
      (setq buf (cdr (assoc "buffer" (car (huxi-buffer-list)))))
      (set-buffer buf)
      (save-restriction
        (widen)
        (setq reg (condition-case err
                      (huxi-section-region "Description")
                    (error nil))
              desc (if reg
                       (buffer-substring-no-properties (car reg) (cdr reg))
                     "")
              docstr (format "Input method: %s (`%s' in mode line) for %s\n  %s\n%s\n\n%s\n"
                             (nth 0 elt) (nth 3 elt) (nth 1 elt) (nth 4 elt)
                             desc
                             (substitute-command-keys "\\{map}")))
        (help-setup-xref (list #'describe-input-method (nth 0 elt))
                         (interactive-p))
        (with-output-to-temp-buffer (help-buffer)
          (princ docstr))))))

;;;_ , page format
(defsubst huxi-choice (choice)
  (if (consp choice)
      (car choice)
    choice))

(defun huxi-add-completion ()
  "注意, huxi-add-completion-function 在没有完补全之前返回 nil, 在加完所
有补全之后一定要返回一个 t"
  (if (functionp huxi-add-completion-function)
      (funcall huxi-add-completion-function)
    t))

(defun huxi-format-page ()
  "按当前位置，生成候选词条"
  ;; (message "%S" huxi-current-choices)
  (let ((end (huxi-page-end)))
    (if (car huxi-current-choices)
        (let* ((start (1- (huxi-page-start)))
               (choices (car huxi-current-choices))
               (choice (huxi-subseq choices start end))
               (pos (1- (min huxi-current-pos (length choices))))
               (i 0))
          (setq huxi-current-str (huxi-choice (nth pos choices)))
          (setq huxi-guidance-str
                (funcall huxi-format-function huxi-current-key (huxi-current-page)
                         (huxi-total-page) choice))
          ;; (message "%d, %s, %s" pos huxi-current-str huxi-guidance-str)
          (huxi-show))
      (setq huxi-current-str huxi-current-key)
      (setq huxi-guidance-str
            (concat huxi-current-key
                    (if (cdr (assoc "completions" (cdr huxi-current-choices)))
                        (format "[%s]: "
                                (mapconcat 'identity
                                           (cdr (assoc
                                                 "completions"
                                                 (cdr huxi-current-choices)))
                                           "")))))
      (huxi-show))))

(defun huxi-current-page ()
  (1+ (/ (1- huxi-current-pos) huxi-page-length)))

(defun huxi-total-page ()
  (1+ (/ (1- (length (car huxi-current-choices))) huxi-page-length)))

(defun huxi-page-start ()
  "计算当前所在页的第一个词条的位置"
  (let ((pos (min (length (car huxi-current-choices)) huxi-current-pos)))
    (1+ (- pos (huxi-mod pos huxi-page-length)))))

(defun huxi-page-end (&optional finish)
  "计算当前所在页的最后一个词条的位置，如果 huxi-current-choices 用
完，则检查是否有补全。如果 FINISH 为 non-nil，说明，补全已经用完了"
  (let* ((whole (length (car huxi-current-choices)))
         (len huxi-page-length)
         (pos huxi-current-pos)
         (last (+ (- pos (huxi-mod pos len)) len)))
    (if (< last whole)
        last
      (if finish
          whole
        (huxi-page-end (huxi-add-completion))))))

;;;_ , commands
(defun huxi-next-page (arg)
  (interactive "p")
  (if (> (length huxi-current-key) 0)
      (let ((new (+ huxi-current-pos (* huxi-page-length arg) 1)))
        (setq huxi-current-pos (if (> new 0) new 1)
              huxi-current-pos (huxi-page-start))
        (huxi-format-page))
    (message "%c" last-command-event)
    (huxi-append-string (huxi-translate last-command-event))
    (huxi-terminate-translation)))

(defun huxi-previous-page (arg)
  (interactive "p")
  (huxi-next-page (- arg)))

(defun huxi-delete-last-word ()
  (interactive)
  (delete-backward-char huxi-current-length))

(defun huxi-delete-last-char ()
  (interactive)
  (if (> (length huxi-current-key) 1)
      (progn
        (setq huxi-current-key (substring huxi-current-key 0 -1))
        (funcall huxi-handle-function))
    (setq huxi-current-str "")
    (huxi-terminate-translation)))

(defun huxi-self-insert-command ()
  "如果在 huxi-first-char 列表中，则查找相应的词条，否则停止转换，插入对应的字符"
  (interactive "*")
  (if (if (huxi-string-emptyp huxi-current-key)
          (member last-command-event huxi-first-char)
        (member last-command-event huxi-total-char))
      (progn
        (if (= (length huxi-current-key) huxi-max-codes)
            (progn
              (when (< 1 (length (car huxi-current-choices)))
                (huxi-delete-overlays)
                (insert (car (car huxi-current-choices))  )
                (huxi-setup-overlays)
                )
              (setq huxi-current-key (char-to-string last-command-event)))
          (setq huxi-current-key (concat huxi-current-key (char-to-string last-command-event))))

        (funcall huxi-handle-function)

        ;; (when (= (length huxi-current-key) 1)
        ;;   (when (member huxi-current-key (list "a" "e" "i" "o" "u"))
        ;;     (huxi-terminate-translation)
        ;;     ;; (message "")
        ;;     ))

        (let ((cl (length (assoc "completions" huxi-current-choices))))
          (when (or (= 1 cl) (= 2 cl))
            (when (= 1 (length (car huxi-current-choices)))
              (huxi-j1)
              (huxi-show)
              )
            ))
        ;; 没有词时只显示key
        (when (string= huxi-current-str huxi-current-key)
          (setq huxi-current-str ""))
        )
    (huxi-append-string (huxi-translate last-command-event))
    (huxi-terminate-translation)))

(defun huxi-insert ()
  (interactive)
  (insert " "))

(defun huxi-insert2 ()
  (interactive)
  (insert " `")
  )

(defun huxi-punc1 ()
  (interactive)
  (call-interactively 'huxi-select-current)
  (huxi-append-string (huxi-translate ?,)))

(defun huxi-punc2 ()
  (interactive)
  (call-interactively 'huxi-select-current)
  (huxi-append-string (huxi-translate ?.)))

(defun huxi-select-current ()
  "如果没有可选项，而且是用空格来绑定这个键，就插入空格，否则选择第一
个词条"
  (interactive)
  (if (null (car huxi-current-choices))
      (setq huxi-current-str
            (if (> (length huxi-current-str) 0)
                ""
              (huxi-translate last-command-event)))
    (huxi-remember-select))
  (huxi-terminate-translation)

  ;; 输入空格时，自动切换到英文状态
  (when (and huxi-quick-en (string= huxi-current-str " "))
    (setq huxi-quick-en-on t)
    (call-interactively 'toggle-input-method)
    (call-interactively 'huxi-insert)))

(defun huxi-remember-select (&optional pos)
  (let ((rest (emms-delete-if (lambda (p) (string= (car p) "pos"))
                              (cdr huxi-current-choices))))
    (setq rest (append rest (list (cons "pos" (or pos
                                                  huxi-current-pos)))))
    (puthash huxi-current-key (cons (car huxi-current-choices)
                                    rest) (huxi-history))))

(defun huxi-number-select-char (char)
  (if (car huxi-current-choices)
      (let ((index (+ (huxi-page-start) (- char ?2)))
            (end (huxi-page-end)))
        (if (= char ?0)
            (setq index (+ index 10)))
        (if (>= index end)
            (huxi-show)
          (huxi-remember-select (1+ index))
          (setq huxi-current-str (concat huxi-current-temp
                                         (huxi-choice (nth index (car huxi-current-choices)))
                                         ))
          (huxi-terminate-translation)
          (setq huxi-current-temp "")
          ))
    (huxi-append-string (char-to-string char))
    (huxi-terminate-translation)))

(defun huxi-j1 ()
  "select firest"
  (interactive)
  (if (car huxi-current-choices)
      (let ((index (+ (huxi-page-start) (- ?1 ?2)))
            (end (huxi-page-end)))
        (if (>= index end)
            (huxi-show)
          (huxi-remember-select (1+ index))
          (setq huxi-current-str (concat huxi-current-temp
                                         (huxi-choice (nth index (car huxi-current-choices)))
                                         ))
          (huxi-terminate-translation)
          ))
    ;; (when huxi-quick-en
    ;;   (setq huxi-quick-en-on t)
    ;;   (call-interactively 'toggle-input-method)
    ;;   (call-interactively 'huxi-insert))

    (call-interactively 'huxi-insert)
    (huxi-terminate-translation)
    )
  (setq huxi-current-temp "")
  )

(defun huxi-j2 ()
  "english toggle with ` "
  (interactive)
  (if huxi-quick-en-on
      (progn 
        (call-interactively 'toggle-input-method)
        (insert "` ")
        (setq huxi-quick-en-on nil)
        )
    (progn
      (if  current-input-method
          (progn
            (setq huxi-quick-en-on t)
            (call-interactively 'toggle-input-method)
            (call-interactively 'huxi-insert2)
            )
        (insert "`")
        ))))

(defun huxi-number-select ()
  "如果没有可选项，插入数字，否则选择对应的词条"
  (interactive)
  (huxi-number-select-char last-command-event)
  )

(defun huxi-number-select-char-j1 ()
  "如果没有可选项，插入数字，否则选择对应的词条"
  (interactive)
  (huxi-number-select-char ?1))

(defun huxi-number-select-char-k2 ()
  "如果没有可选项，插入数字，否则选择对应的词条"
  (interactive)
  (huxi-number-select-char ?2))

(defun huxi-number-select-char-l3 ()
  "如果没有可选项，插入数字，否则选择对应的词条"
  (interactive)
  (huxi-number-select-char ?3))

(defun huxi-number-select-char-u4 ()
  "如果没有可选项，插入数字，否则选择对应的词条"
  (interactive)
  (huxi-number-select-char ?4))

(defun huxi-number-select-char-i5 ()
  "如果没有可选项，插入数字，否则选择对应的词条"
  (interactive)
  (huxi-number-select-char ?5))

(defun huxi-number-select-char-o6 ()
  "如果没有可选项，插入数字，否则选择对应的词条"
  (interactive)
  (huxi-number-select-char ?6))

(defun huxi-quit-clear ()
  (interactive)
  (setq huxi-current-str "")
  (huxi-terminate-translation))

(defun huxi-quit-no-clear ()
  (interactive)
  (setq huxi-current-str huxi-current-key)
  (huxi-terminate-translation))

(defun huxi-terminate-translation ()
  "Terminate the translation of the current key."
  (setq huxi-translating nil)
  (huxi-delete-region)
  (setq huxi-current-choices nil)
  (setq huxi-guidance-str "")
  (when huxi-use-tooltip
    (x-hide-tip)))

;;;_ , huxi-handle-string
(defun huxi-handle-string ()
  (if (and (functionp huxi-stop-function)
           (funcall huxi-stop-function))
      (progn
        (setq unread-command-events
              (list (aref huxi-current-key (1- (length huxi-current-key)))))
        (huxi-terminate-translation))
    (setq huxi-current-choices (huxi-get huxi-current-key)
          huxi-current-pos
          (if (huxi-get-option 'record-position)
              (cdr (assoc "pos" (cdr huxi-current-choices)))
            1))
    ;; (message "cccc: %S" huxi-current-choices )
    (huxi-format-page)
    ;; (message "dddd: %S" huxi-current-choices )

    ))

(defun huxi-translate (char)
  (if (functionp huxi-translate-function)
      (funcall huxi-translate-function char)
    (char-to-string char)))

(defun huxi-exit-from-minibuffer ()
  (deactivate-input-method)
  (if (<= (minibuffer-depth) 1)
      (remove-hook 'minibuffer-exit-hook 'huxi-exit-from-minibuffer)))

(defun huxi-setup-overlays ()
  (let ((pos (point)))
    (if (overlayp huxi-overlay)
        (move-overlay huxi-overlay pos pos)
      (setq huxi-overlay (make-overlay pos pos))
      (if input-method-highlight-flag
          (overlay-put huxi-overlay 'face 'huxi-string-face)))))

(defun huxi-delete-overlays ()
  (if (and (overlayp huxi-overlay) (overlay-start huxi-overlay))
      (delete-overlay huxi-overlay)))

(defun huxi-show ()
  (unless enable-multibyte-characters
    (setq huxi-current-key nil
          huxi-current-str nil)
    (error "Can't input characters in current unibyte buffer"))
  (huxi-delete-region)

  (setq huxi-current-length
        (length huxi-current-str))

  ;; 显示当前选择词条
  (when huxi-show-first
    (insert huxi-current-str)
    )

  (if (eq (selected-window) (minibuffer-window))
      (insert huxi-current-str)
    )

  (move-overlay huxi-overlay (overlay-start huxi-overlay) (point))
  ;; Then, show the guidance.
  (when (and (not input-method-use-echo-area)
             (null unread-command-events)
             (null unread-post-input-method-events))
    (if (eq (selected-window) (minibuffer-window))
        ;; Show the guidance in the next line of the currrent
        ;; minibuffer.
        (huxi-minibuffer-message
         (format "  [%s]\n%s"
                 current-input-method-title huxi-guidance-str))
      ;; Show the guidance in echo area without logging.
      (let ((message-log-max nil))
        (if huxi-use-tooltip
            (let ((pos (string-match ": " huxi-guidance-str)))
              (if pos
                  (setq huxi-guidance-str
                        (concat (substring huxi-guidance-str 0 pos)
                                "\n"
                                (make-string (/ (- (string-width huxi-guidance-str) pos) 2) (decode-char 'ucs #x2501))
                                "\n"
                                (substring huxi-guidance-str (+ pos 2)))))
              (huxi-show-tooltip huxi-guidance-str))
          (message "%s" huxi-guidance-str))))))

(defun huxi-make-guidance-frame ()
  "Make a new one-line frame for guidance."
  (let* ((fparam (frame-parameters))
         (top (cdr (assq 'top fparam)))
         (border (cdr (assq 'border-width fparam)))
         (internal-border (cdr (assq 'internal-border-width fparam)))
         (newtop (- top
                    (frame-char-height) (* internal-border 2) (* border 2))))
    (if (< newtop 0)
        (setq newtop (+ top (frame-pixel-height) internal-border border)))
    (make-frame (append '((user-position . t) (height . 1)
                          (minibuffer)
                          (menu-bar-lines . 0) (tool-bar-lines . 0))
                        (cons (cons 'top newtop) fparam)))))

(defun huxi-minibuffer-message (string)
  (message nil)
  (let ((point-max (point-max))
        (inhibit-quit t))
    (save-excursion
      (goto-char point-max)
      (insert string)
      )
    (sit-for 1000000)
    (delete-region point-max (point-max))
    (when quit-flag
      (setq quit-flag nil
            unread-command-events '(7)))))

(defun huxi-input-method (key)
  (if (or buffer-read-only
          overriding-terminal-local-map
          overriding-local-map)
      (list key)
    ;; (message "call with key: %c" key)
    (huxi-setup-overlays)
    (let ((modified-p (buffer-modified-p))
          ;; (buffer-undo-list t)      ;; cy: 注释掉了 undo all
          (inhibit-modification-hooks t))
      (unwind-protect
          (let ((input-string (huxi-start-translation key)))
            ;;   (message "input-string: %s" input-string)
            (setq huxi-guidance-str "")
            (when (and (stringp input-string)
                       (> (length input-string) 0))
              (if input-method-exit-on-first-char
                  (list (aref input-string 0))
                (huxi-input-string-to-events input-string))))
        (huxi-delete-overlays)
        (set-buffer-modified-p modified-p)
        ;; Run this hook only when the current input method doesn't
        ;; require conversion. When conversion is required, the
        ;; conversion function should run this hook at a proper
        ;; timing.
        (run-hooks 'input-method-after-insert-chunk-hook)))))

(defun huxi-start-translation (key)
  "Start translation of the typed character KEY by the current package.
Return the input string."
  ;; Check the possibility of translating KEY.
  ;; If KEY is nil, we can anyway start translation.
  (if (or (integerp key) (null key))
      ;; OK, we can start translation.
      (let* ((echo-keystrokes 0)
             (help-char nil)
             (overriding-terminal-local-map (huxi-mode-map))
             (generated-events nil)
             (input-method-function nil)
             (modified-p (buffer-modified-p))
             last-command-event last-command this-command)
        (setq huxi-current-str ""
              huxi-current-key ""
              huxi-translating t)
        (if key
            (setq unread-command-events
                  (cons key unread-command-events)))
        (while huxi-translating
          (set-buffer-modified-p modified-p)
          (let* ((prompt (if input-method-use-echo-area
                             (format "%s%s %s"
                                     (or input-method-previous-message "")
                                     huxi-current-key
                                     huxi-guidance-str)))
                 (keyseq (read-key-sequence prompt nil nil t))
                 (cmd (lookup-key (huxi-mode-map) keyseq)))
            ;;             (message "key: %s, cmd:%s\nlcmd: %s, lcmdv: %s, tcmd: %s"
            ;;                      key cmd last-command last-command-event this-command)
            (if (if key
                    (commandp cmd)
                  (eq cmd 'huxi-self-insert-command))
                (progn
                  ;; (message "keyseq: %s" keyseq)
                  (setq last-command-event (aref keyseq (1- (length keyseq)))
                        last-command this-command
                        this-command cmd)
                  (setq key t)
                  (condition-case err
                      (call-interactively cmd)
                    (error (message "%s" (cdr err)) (beep))))
              ;; KEYSEQ is not defined in the translation keymap.
              ;; Let's return the event(s) to the caller.
              (setq unread-command-events
                    (string-to-list (this-single-command-raw-keys)))
              ;; (message "unread-command-events: %s" unread-command-events)
              ;; 处理其它输入
              (setq huxi-current-str "")
              (huxi-terminate-translation)
              )))
        ;;    (1message "return: %s" huxi-current-str)
        huxi-current-str
        )
    ;; Since KEY doesn't start any translation, just return it.
    ;; But translate KEY if necessary.
    (char-to-string key)))

(defun huxi-input-string-to-events (str)
  (let ((events (mapcar
                 (lambda (c)
                   ;; This gives us the chance to unify on input
                   ;; (e.g. using ucs-tables.el).
                   (or (and translation-table-for-input
                            (aref translation-table-for-input c))
                       c))
                 str)))
    (if (or (get-text-property 0 'advice str)
            (next-single-property-change 0 'advice str))
        (setq events
              (nconc events (list (list 'huxi-advice str)))))
    events))

(defun huxi-advice (args)
  (interactive "e")
  (let* ((string (nth 1 args))
         (func (get-text-property 0 'advice string)))
    (if (functionp func)
        (funcall func string))))

(global-set-key [huxi-advice] 'huxi-advice)

;;; borrow from completion-ui
(defun huxi-frame-posn-at-point (&optional position window)
  "Return pixel position of top left corner of glyph at POSITION,
relative to top left corner of frame containing WINDOW. Defaults
to the position of point in the selected window."
  (unless window (setq window (selected-window)))
  (unless position (setq position (window-point window)))
  (let ((x-y (posn-x-y (posn-at-point position window)))
        (edges (window-inside-pixel-edges window)))
    (cons (+ (car x-y) (car  edges))
          (+ (cdr x-y) (cadr edges)))))

(defface huxi-tooltip-face '((((class color)) :inherit tooltip))
  "face to display items"
  :group 'huxi)

(defun huxi-show-tooltip (text)
  "Show tooltip text near cursor."
  (let ((pos (huxi-frame-posn-at-point))
        (fg (face-attribute 'huxi-tooltip-face :foreground nil 'tooltip))
        (bg (face-attribute 'huxi-tooltip-face :background nil 'tooltip))
        (params tooltip-frame-parameters)
        ;; seem the top position should add 65 pixel to make
        ;; the text display under the baseline of cursor
        (top-adjust 65)
        (frame-height (frame-pixel-height))
        (frame-width (frame-pixel-width))
        (lines (split-string text "\n"))
        width height left top)
    (setq width (* (frame-char-width) (apply 'max (mapcar 'string-width lines)))
          height (* (frame-char-height) (length lines)))
    (setq left (frame-parameter nil 'left)
          top (frame-parameter nil 'top))
    ;; if the cursor is at near the right frame fringe or at bottom
    ;; of the bottom fringe, move the frame to
    ;; -frame-width or -frame-height from right or bottom
    (if (< (- frame-width (car pos)) width)
        (setq left (+ left (max 0 (- frame-width width))))
      (setq left (+ left (car pos))))
    (if (< (- frame-height (cdr pos)) (+ height top-adjust))
        (setq top (+ top (max 0 (- frame-height height))))
      (setq top (+ top (cdr pos))))
    (setq top (+ top top-adjust))
    (when (stringp fg)
      (setq params (append params `((foreground-color . ,fg)
                                    (border-color . ,fg)))))
    (when (stringp bg)
      (setq params (append params `((background-color . ,bg)))))
    (setq params (append params `((left . ,left) (top . ,top))))
    (x-show-tip (propertize text 'face 'huxi-tooltip-face)
                nil params huxi-tooltip-timeout)))

(register-input-method "huxi" "euc-cn" 'huxi-use-package
                       "呼吸" "Huxi Emacs 中文输入法" "cy-3500.txt")
(provide 'huxi)
