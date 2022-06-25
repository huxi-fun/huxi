;;; huxi-extra.el

;;; Commentary:

;;; Code:

(eval-when-compile
  (require 'cl))
(require 'huxi)

(defvar huxi-punc-escape-list
  (number-sequence ?0 ?9)
  "Punctuation will not insert after this characters.
If you don't like this funciton, set the variable to nil")

(defvar huxi-insert-ascii-char (cons ?\; "；")
  "*Key used for `huxi-insert-ascii'.")

(defvar huxi-punc-translate-p t 
  "*Non-nil means will translate punctuation.")

(defvar huxi-lispy-left "[([{]"
  "Opening delimiter.")

(defvar huxi-lispy-right "[])}]"
  "Closing delimiter.")

;;;_. handle punctuation
(defun huxi-read-punctuation (package)
  (let ((huxi-current-package package)
	      buf punc-list punc)
    (setq buf (cdr (assoc "buffer" (car (huxi-buffer-list)))))
    (save-excursion
      (set-buffer buf)
      (save-restriction
        (widen)
        (let ((region (huxi-section-region "Punctuation")))
          (goto-char (car region))
          (while (< (point) (cdr region))
            (setq punc (huxi-line-content))
            (if (> (length punc) 3)
                (error "标点不支持多个转换！"))
            (add-to-list 'punc-list punc)
            (forward-line 1)))))
    punc-list))

(defun huxi-punc-translate (punc-list char)
  (if huxi-punc-translate-p
      (cond ((< char ? ) "")
            ((and huxi-insert-ascii-char
                  (= char (car huxi-insert-ascii-char)))
             (char-to-string char))
            (t (let ((str (char-to-string char))
                     punc)
                 (if (and (not (member (char-before) huxi-punc-escape-list))
                          (setq punc (cdr (assoc str punc-list))))
                     (progn
                       (if (= char (char-before))
                           (delete-char -1))
                       (if (= (safe-length punc) 1)
                           (car punc)
                         (setcdr (cdr punc) (not (cddr punc)))
                         (if (cddr punc)
                             (car punc)
                           (nth 1 punc))))
                   str))))
    (char-to-string char)))

(defun huxi-punc-translate-toggle (arg)
  (interactive "P")
  (setq huxi-punc-translate-p
        (if (null arg)
            (not huxi-punc-translate-p)
          (> (prefix-numeric-value arg) 0))))

;;;_. 一个快速插入英文的命令。按自己的需要绑定
(defun huxi-insert-ascii ()
  (interactive)
  (if current-input-method
      (let (c)
        (message "英文：")
        (setq c (read-event))
        (cond ((= c ? ) (insert (cdr huxi-insert-ascii-char)))
              ((= c ?\r) (insert-char (car huxi-insert-ascii-char) 1))
              (t
               (setq unread-command-events (list last-input-event))
               (insert (read-from-minibuffer "英文：")))))
    (call-interactively 'self-insert-command)))

(defun huxi-insert-ascii-first ()
  "切换到英文状态时，先显示第一个字母"
  (interactive)
  (if current-input-method
      (let (c)
	      (message (concat "英文：" (char-to-string last-input-event)))
	      (insert (char-to-string last-input-event))
        (setq c (read-event))
        (cond ((= c ? ) (insert (cdr huxi-insert-ascii-char)))
              ((= c ?\r) (insert-char (car huxi-insert-ascii-char) 1))
              (t
               (setq unread-command-events (list last-input-event))
               (insert (read-from-minibuffer (concat "英文：" (char-to-string last-command-event)))))))
    (call-interactively 'self-insert-command)))

(defun huxi-en-toggle ()
  "用于输入大写字母时切换输入法"
  (interactive)
  (if current-input-method
      (progn
	      (insert (char-to-string last-input-event))
        (call-interactively 'toggle-input-method))
    (call-interactively 'self-insert-command)))


(defun huxi-toggle ()
  "切换输入法"
  (interactive)
  (if current-input-method
      (huxi-quit-clear))
  (toggle-input-method))

(defun huxi-toggle2 ()
  "切换输入法"
  (interactive)
  (if current-input-method
      (huxi-quit-clear))
  (toggle-input-method)
  (insert " "))

(defun huxi-quick-en-space-off ()
  "关闭快速英文状态"
  (interactive)
  (insert " ")
  (when huxi-quick-en-on
    (toggle-input-method)
    (setq huxi-quick-en-on nil)))

(defun huxi-evil-normal-toggle ()
  "Evil 中，在 normal 状态下关闭输入法"
  (interactive)
  (call-interactively 'evil-insert)
  (if current-input-method
      (progn
        (call-interactively 'toggle-input-method)))
  (call-interactively 'evil-force-normal-state))

(defun huxi-evil-insert-entry-toggle ()
  (interactive)
  (when (looking-at huxi-lispy-left)
    (if current-input-method
        (progn
          (call-interactively 'toggle-input-method))))
  (when (looking-back huxi-lispy-right
                      (line-beginning-position))
    (if current-input-method
        (progn
          (call-interactively 'toggle-input-method)))))

;;;_. load and save history
(defun huxi-load-history (history-file package)
  (let* ((huxi-current-package package)
         (history (huxi-history))
         item)
    (when (file-exists-p history-file)
      (with-current-buffer (find-file-noselect history-file)
        (goto-char (point-min))
        (while (not (eobp))
          (if (and (setq item (huxi-line-content))
                   (= (length item) 2))
              (puthash (car item)
                       `(nil ("pos" . ,(string-to-number (cadr item))))
                       history))
          (forward-line 1))
        (kill-buffer (current-buffer))))))

(defun huxi-save-history (history-file package)
  (interactive)
  (let* ((huxi-current-package package)
         (history (huxi-history)))
    (with-temp-buffer
      (erase-buffer)
      (let (pos)
        (maphash (lambda (key val)
                   (unless (or (huxi-string-emptyp key)
                               (= (setq pos (cdr (assoc "pos" (cdr val)))) 1))
                     (insert key " " (number-to-string pos) "\n")))
                 history))
      (write-file history-file))))

;;;_. 增加两个快速选择的按键
(defun huxi-quick-select-1 ()
  "如果没有可选项，插入数字，否则选择对应的词条."
  (interactive)
  (if (car huxi-current-choices)
      (let ((index (huxi-page-start))
            (end (huxi-page-end)))
        (if (>= index end)
            (huxi-append-string (huxi-translate last-command-event))
          (huxi-remember-select (1+ index))
          (setq huxi-current-str (huxi-choice (nth index (car huxi-current-choices))))))
    (huxi-append-string (huxi-translate last-command-event)))
  (huxi-terminate-translation)
  )

(defun huxi-quick-select-2 ()
  "如果没有可选项，插入数字，否则选择对应的词条."
  (interactive)
  (if (car huxi-current-choices)
      (let ((index (1+ (huxi-page-start)))
            (end (huxi-page-end)))
        (if (>= index end)
            (huxi-append-string (huxi-translate last-command-event))
          (huxi-remember-select (1+ index))
          (setq huxi-current-str (huxi-choice (nth index (car huxi-current-choices))))))
    (huxi-append-string (huxi-translate last-command-event)))
  (huxi-terminate-translation))

(defun huxi-describe-char (pos package)
  (interactive
   (list (point)
         (if (eq input-method-function 'huxi-input-method)
             (huxi-package-name)
           (let (huxi-current-package)
             (setq huxi-current-package
                   (if (= (length huxi-package-list) 1)
                       (cdar huxi-package-list)
                     (assoc
                      (completing-read "In package: "
                                       huxi-package-list nil t
                                       (caar huxi-package-list))
                      huxi-package-list)))
             (huxi-package-name)))))
  (if (>= pos (point-max))
      (error "No character follows specified position"))
  (let ((char (char-after pos))
        (func (intern-soft (format "%s-get-char-code" package)))
        code)
    (when func
      (setq code (funcall func char))
      (if code
          (message "Type %S to input %c for input method %s"
                   code char package)
        (message "Can't find char code for %c" char)))))

;;;_. char table
(defun huxi-make-char-table (chars table)
  "Set CHARS of `huxi-char-database' in TABLE."
  (dolist (char chars)
    (let ((code (car char)))
      (dolist (c (cdr char))
        (set (intern c table) code)))))

(defsubst huxi-get-char-code (char table)
  "Get the code of the character CHAR in TABLE."
  (symbol-value (intern-soft (char-to-string char) table)))

(provide 'huxi-extra)
