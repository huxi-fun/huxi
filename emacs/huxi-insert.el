(defun huxi-insert-pa ()
  "插入()"
  (interactive)
  (insert "()")
  (backward-char 1))

(defun huxi-insert-pa2 ()
  "插入()"
  (interactive)
  (insert "()"))

(defun huxi-insert-pa3s ()
  "插入 {}"
  (interactive)
  (insert "{}")
  (backward-char 1))

(defun huxi-insert-pa3 ()
  "插入{}"
  (interactive)
  (insert "{}")
  (backward-char 1)
  (newline)
  (newline)
  (tab-indent-or-complete)
  (previous-line)
  (tab-indent-or-complete)
  (call-interactively 'evil-insert))

(defun huxi-insert-pa4 ()
  "插入();"
  (interactive)
  (insert "();"))

(defun huxi-insert-yin ()
  "插入\"\""
  (interactive)
  ;; (forward-char 1)
  (insert "\"\"")
  (backward-char 1))

(defun huxi-insert-yin2 ()
  "插入\"\";"
  (interactive)
  ;; (forward-char 1)
  (insert "\"\";")
  (backward-char 2))

(defun huxi-insert-I ()
  "插入 ||"
  (interactive)
  ;; (forward-char 1)
  (insert "||")
  (backward-char 1))

(defun huxi-insert-<> ()
  "插入 <>"
  (interactive)
  ;; (forward-char 1)
  (insert "<>")
  (backward-char 1))

(defun huxi-insert-II ()
  "插入 ::"
  (interactive)
  (insert "::"))

(defun huxi-insert-> ()
  "插入 ->"
  (interactive)
  (insert " -> "))

(defun huxi-insert-sta ()
  "插入&'static "
  (interactive)
  (insert "&'static "))

(defun huxi-insert-=s ()
  "插入 = "
  (interactive)
  (insert " = "))

(defun huxi-insert-sharp ()
  "插入#"
  (interactive)
  (insert "#"))

(defun huxi-insert-star ()
  "插入*"
  (interactive)
  (insert "*"))

(defun huxi-insert-= ()
  "插入="
  (interactive)
  (insert "="))

(defun huxi-insert-mao ()
  "插入 : "
  (interactive)
  (insert ": "))

(defun huxi-insert-== ()
  "插入 == "
  (interactive)
  (insert " == "))

(defun huxi-insert-=> ()
  "插入 => "
  (interactive)
  (insert " => "))

(defun huxi-insert-_ ()
  "插入 _"
  (interactive)
  (insert "_"))

(defun huxi-insert-str ()
  "插入: &str, "
  (interactive)
  (insert ": &str, "))

(defun huxi-insert-str2 ()
  "插入&str"
  (interactive)
  (insert "&str"))

(defun huxi-insert-sharp ()
  "插入#"
  (interactive)
  (insert "#"))

(defun huxi-insert-? ()
  "插入 ? "
  (interactive)
  (insert "?"))

(defun huxi-insert-fn ()
  "插入 fn "
  (interactive)
  (insert "fn "))
                                        ;
(defun huxi-insert-& ()
  "插入 &"
  (interactive)
  (insert "&"))

(defun huxi-insert-u ()
  "插入 .unwrap()"
  (interactive)
  (insert ".unwrap()"))

(defun huxi-insert-bracket ()
  "插入方括号"
  (interactive)
  (insert "[]")
  (backward-char 1))

(defun huxi-insert-cc ()
  "插入 ，"
  (interactive)
  (insert "，"))

(defun huxi-insert-cj ()
  "插入 。"
  (interactive)
  (insert "。"))

(defun huxi-insert-p1 ()
  "插入("
  (interactive)
  (insert "("))
(defun huxi-insert-p2 ()
  "插入 )"
  (interactive)
  (insert ")"))
(defun huxi-insert-s1 ()
  "插入 {"
  (interactive)
  (insert "{"))
(defun huxi-insert-s2 ()
  "插入 }"
  (interactive)
  (insert "}"))
(provide 'huxi-insert)
