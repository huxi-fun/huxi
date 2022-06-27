;;; huxi-table.el


;;; Commentary:

;; - punctuation-list: A symbol to translate punctuation
;; - translate-chars: The first letter which will invoke reverse
;;                   search the code for char
;; - max-codes: max input string length
;; - char-table: a obarray to search code for char
;; - all-completion-limit: A minimal length to add all completions
;; - table-create-word-function
;; 
;; - table-user-file
;; - table-history-file

;;; Code:

(eval-when-compile
  (require 'cl))
(require 'huxi)
(require 'huxi-extra)

(defun huxi-table-translate (char)
  (huxi-punc-translate (symbol-value (huxi-get-option 'punctuation-list))
                      char))

(defun huxi-table-get-char-code (char)
  (huxi-get-char-code char (huxi-get-option 'char-table)))

(defun huxi-table-format (key cp tp choice)
  (if (memq (aref key 0) (huxi-get-option 'translate-chars))
      (setq choice
            (mapcar (lambda (c)
                      (if (consp c)
                          (setq c (car c)))
                      (cons c
                            (huxi-table-get-char-code (aref c 0))))
                    choice)))
  (let ((i 0))
    (format "%s[%d/%d]: %s"
            key  cp tp
            (mapconcat 'identity
                       (mapcar
                        (lambda (c)
                          (setq i (1+ i))
                          (format "%s %s "
                                  (propertize (number-to-string i) 'face 'huxi-comment-face)
                                  (if (consp c)
                                      (concat
                                       (if (= i 1)
                                           (propertize (car c) 'face 'huxi-highlight-candidate-face)
                                         (propertize (car c) 'face 'huxi-default-face)
                                         )
                                       ;; (car c)
                                       " "
                                       (propertize (cdr c) 'face 'huxi-indicator-face)
                                       )
                                    (propertize c 'face 'huxi-highlight-candidate-face)


                                    )))
                        choice) "   "))))

;;;_. 增加补全
(defun huxi-table-add-completion ()
  (if (or (= (length (assoc "completions" huxi-current-choices)) 1)
          (= (1+ (seq-count (lambda (elt) (consp elt))
                            (car huxi-current-choices)) )
             (length (assoc "completions" huxi-current-choices))))
      t
    (let ((reg (concat "^" (regexp-quote huxi-current-key)))
          (len (length huxi-current-key))
          (package huxi-current-package)
          (key huxi-current-key)
          line completion)
      (save-excursion
        (dolist (buf (mapcar 'cdar (huxi-buffer-list)))
          (set-buffer buf)
          (setq huxi-current-package package)
          (beginning-of-line)
          (if (or (string= (huxi-code-at-point) key)
                  (not (looking-at reg)))
              (forward-line 1))
          (while (looking-at reg)
            (setq line (huxi-line-content))
            (mapc (lambda (c)
                    (when (or (>= len (huxi-get-option 'all-completion-limit))
                              (= (length c) 1) (= (length c) 2) )  ;; 重点
                      (push (cons c (substring
                                     (car line)
                                     len))
                            completion)))
                  (cdr line))
            (forward-line 1))))
      (setq completion (sort (delete-dups (nreverse completion))
                             (lambda (a b)
                               (< (length (cdr a)) (length (cdr b))))))
      (setcar huxi-current-choices (append (car huxi-current-choices)
                                           completion))
      t)
    )
  )

(defun huxi-table-stop-function ()
  (if (memq (aref huxi-current-key 0) (huxi-get-option 'translate-chars))
      nil
    (> (length huxi-current-key)
       huxi-max-codes
       )))

(defun huxi-table-active-function ()
  (setq huxi-add-completion-function 'huxi-table-add-completion
        huxi-translate-function 'huxi-table-translate
        huxi-format-function 'huxi-table-format
        huxi-stop-function 'huxi-table-stop-function))

;; user file and history file
;;;_. huxi-im-add-user-file
(defun huxi-table-add-user-file (file)
  (when file
    (let* ((buflist (huxi-buffer-list))
           (ufile (expand-file-name file))
           user-buffer)
      (or (file-exists-p ufile)
          (setq ufile (locate-file file load-path)))
      (when (and ufile (file-exists-p ufile))
        ;; make sure the file not load again
        (mapc (lambda (buf)
                (if (string= (expand-file-name (cdr (assoc "file" buf)))
                             ufile)
                    (setq user-buffer (cdr (assoc "buffer" buf)))))
              buflist)
        (unless user-buffer
          (setq file (huxi-read-file ufile (format huxi-buffer-name-format
                                                  (huxi-package-name))))
          (huxi-make-char-table (huxi-table-get-user-char (cdar file)) (huxi-get-option 'char-table))
          (nconc buflist (list file))
          (huxi-set-option 'table-user-file (cons ufile (cdar file))))))))

(defun huxi-table-get-user-char (buf)
  "Add user characters. Currently huxi-im may not contain all
chinese characters, so if you want more characters to input, you
can add here."
  (let (line chars)
    (save-excursion
      (set-buffer buf)
      (goto-char (point-min))
      (while (not (eobp))
        (setq line (huxi-line-content))
        (forward-line 1)
        (if (and (= (length (cadr line)) 1)
                 (> (length (car line)) 2))
            (push line chars)))
      chars)))

(defun huxi-table-load-history (his-file)
  (when (and his-file (file-exists-p his-file))
    (ignore-errors
      (huxi-load-history his-file huxi-current-package)
      (huxi-set-option 'record-position t)
      (huxi-set-option 'table-history-file his-file))))

(defun huxi-table-save-history ()
  "Save history and user files."
  (dolist (package huxi-package-list)
    (let* ((huxi-current-package (cdr package))
           (his-file (huxi-get-option 'table-history-file))
           (user-file (huxi-get-option 'table-user-file)))
      (when (and his-file
                 (file-exists-p his-file)
                 (file-writable-p his-file))
        (huxi-save-history his-file huxi-current-package))
      (when (and user-file
                 (file-exists-p (car user-file))
                 (file-writable-p (car user-file)))
        (with-current-buffer (cdr user-file)
          (save-restriction
            (widen)
            (write-region (point-min) (point-max) (car user-file))))))))
;; 按 TAB 显示补全
(defun huxi-table-show-completion ()
  (interactive)
  (if (eq last-command 'huxi-table-show-completion)
      (ignore-errors
        (with-selected-window (get-buffer-window "*Completions*")
          (scroll-up)))
    (if (or (= (length huxi-current-key) 1) (= (aref huxi-current-key 0) ?z))
        nil
      (while (not (huxi-add-completion)))
      (let ((choices (car huxi-current-choices))
            completion)
        (dolist (c choices)
          (if (listp c)
              (push (list (format "%-4s %s"
                                  (concat huxi-current-key (cdr c))
                                  (car c)))
                    completion)))
        (with-output-to-temp-buffer "*Completions*"
          (display-completion-list
           (all-completions huxi-current-key (nreverse completion))
           huxi-current-key)))))
  (funcall huxi-handle-function))

(defvar huxi-table-minibuffer-map nil)
(defvar huxi-table-save-always nil)
(when (null huxi-table-minibuffer-map)
  (setq huxi-table-minibuffer-map
        (let ((map (make-sparse-keymap)))
          (set-keymap-parent map minibuffer-local-map)
          (define-key map "\C-e" 'huxi-table-minibuffer-forward-char)
          (define-key map "\C-a" 'huxi-table-minibuffer-backward-char)
          map)))

(defun huxi-table-minibuffer-forward-char ()
  (interactive)
  (end-of-line)
  (let ((char (save-excursion
                (set-buffer buffer)
                (char-after end))))
    (when char
      (insert char)
      (incf end))))

(defun huxi-table-minibuffer-backward-char ()
  (interactive)
  (beginning-of-line)
  (let ((char (save-excursion
                (set-buffer buffer)
                (when (>= start (point-min))
                  (decf start)
                  (char-after start)))))
    (when char
      (insert char))))

(defun huxi-table-add-word ()
  "Create a map for word. The default word is the two characters
before cursor. You can use C-a and C-e to add character at the
begining or end of the word.

默认新词为光标前的两个字，通过两个按键延长这个词：
 C-e 在头部加入一个字
 C-a 在尾部加入一个字
"
  (interactive)
  (let* ((buffer (current-buffer))
         (end (point))
         (start (- (point) 2))
         (word (buffer-substring-no-properties
                start end))
         (user-file (huxi-get-option 'table-user-file))
         (func (huxi-get-option 'table-create-word-function))
         choice code words)
    (when func
      (setq word (read-from-minibuffer "加入新词: " word
                                       huxi-table-minibuffer-map)
            code (funcall func word))
      (setq choice (huxi-get code))
      (unless (member word (car choice))
        (if (buffer-live-p (cdr user-file))
            (save-excursion
              (set-buffer (cdr user-file))
              (if (string-match "^\\s-$" (buffer-string))
                  (insert "\n" code " " word)
                (huxi-bisearch-word code (point-min) (point-max))
                (let ((words (huxi-line-content)))
                  (goto-char (line-end-position))
                  (if (string= (car words) code)
                      (insert " " word)
                    (insert "\n" code " " word))))
              (setcar choice (append (car choice) (list word)))
              (if huxi-table-save-always
                  (save-restriction
                    (widen)
                    (write-region (point-min) (point-max) (car user-file)))))
          (error "the user buffer is closed!")))))
  (message nil))

(add-hook 'kill-emacs-hook 'huxi-table-save-history)

(provide 'huxi-table)
