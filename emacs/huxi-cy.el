;;; huxi-cy.el

;;; Features:
;; 1. 能导入输入历史
;; 2. 提供造词的命令
;; 3. 提供候选的单字
;; 4. 拼音输入
;; 5. 处理标点

;;; Commentary:

;;; Code:

(eval-when-compile
  (require 'cl))

(require 'huxi-table)

(defgroup huxi-cy nil
  "huxi input method"
  :group 'huxi)
  
(defcustom huxi-cy-history-file "~/.emacs.d/huxi-history"
  "保存选择的历史记录."
  :type 'file
  :group 'huxi-cy)

(defcustom huxi-cy-user-file "~/.emacs.d/mycy.txt"
  "保存用户自造词."
  :type 'file
  :group 'huxi-cy)

(defcustom huxi-cy-save-always nil
  "是否每次加入新词都要保存.
当然设置为 nil，也会在退出 Emacs 里保存一下的."
  :type 'boolean
  :group 'huxi-cy)

(defcustom huxi-cy-add-all-completion-limit 3
  "在超过输入字符串超过这个长度时会添加所有补全."
  :type 'integer
  :group 'huxi-cy)

(defvar huxi-cy-load-hook nil)
(defvar huxi-cy-package nil)
(defvar huxi-cy-char-table (make-vector 1511 0))
(defvar huxi-cy-punctuation-list nil)
(defvar huxi-cy-initialized nil)

(defun huxi-cy-create-word (word)
  "Insert WORD to database and write into user file."
  (let ((len (length word))
        code)
    (setq code
     (cond
      ((= len 2)
       (concat (substring (huxi-table-get-char-code (aref word 0)) 0 2)
               (substring (huxi-table-get-char-code (aref word 1)) 0 2)))
      ((= len 3)
       (concat (substring (huxi-table-get-char-code (aref word 0)) 0 1)
               (substring (huxi-table-get-char-code (aref word 1)) 0 1)
               (substring (huxi-table-get-char-code (aref word 2)) 0 2)))
      (t
       (concat (substring (huxi-table-get-char-code (aref word 0)) 0 1)
               (substring (huxi-table-get-char-code (aref word 1)) 0 1)
               (substring (huxi-table-get-char-code (aref word 2)) 0 1)
               (substring (huxi-table-get-char-code (aref word (1- (length word)))) 0 1)))))))

;;;_. load it
(unless huxi-cy-initialized
  (setq huxi-cy-package huxi-current-package)
  (setq huxi-cy-punctuation-list
        (huxi-read-punctuation huxi-cy-package))
  ;; (let ((map (huxi-mode-map)))
  ;; (define-key map "\t" 'huxi-table-show-completion)
  ;; (define-key map "[" 'huxi-quick-select-1)
  ;; (define-key map "'" 'huxi-quick-select-2)
  ;; )

  ;; (huxi-table-add-user-file huxi-cy-user-file)
  ;; (huxi-table-load-history huxi-cy-history-file)
  (run-hooks 'huxi-cy-load-hook)
  (huxi-set-option 'table-create-word-function 'huxi-cy-create-word)
  (huxi-set-option 'punctuation-list 'huxi-cy-punctuation-list)
  ;; (huxi-set-option 'translate-chars '(?z)) ;; old
  (huxi-set-option 'all-completion-limit huxi-cy-add-all-completion-limit)
  (huxi-set-option 'char-table huxi-cy-char-table)
  (huxi-set-active-function 'huxi-table-active-function)
  (setq huxi-cy-initialized t))

(provide 'huxi-cy)
