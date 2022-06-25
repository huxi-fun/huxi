(use-package huxi
  :load-path "~/.emacs.d/huxi/emacs"
  :config
  (setq default-input-method 'huxi)
  (require 'huxi-extra)

  ;; 设置中英文切换快捷键， linux 中就是 Alt + Space
  (global-set-key (kbd "M-SPC") 'huxi-toggle)
  (global-set-key (kbd "C-0") 'huxi-toggle)

  ;; 设置临时输入英文快捷键
  (global-set-key (kbd "C-e") 'huxi-insert-ascii)

  ;; 设置中英文标点切换快捷键
  (global-set-key (kbd "C-,") 'huxi-punc-translate-toggle)

  ;; 删除已经输入的单词
  (global-set-key (kbd "M-u") 'huxi-delete-last-word)

  ;; 设置当前显示第一项
  ;;(setq huxi-show-first t)

  ;; 设置光标跟随移动提示， t 或 nil
  (setq huxi-use-tooltip nil)

  (add-hook 'input-method-activate-hook
            (lambda ()
              (set-cursor-color "DeepSkyBlue")
              (setq-local evil-normal-state-cursor '("DeepSkyBlue" box))))

  (add-hook 'input-method-inactivate-hook
            (lambda ()
              (set-cursor-color "red")
              (setq-local evil-normal-state-cursor '("red" box))))

  ;; insert 模式时，遇到括号自动切换英文
  (add-hook 'evil-insert-state-entry-hook 'huxi-evil-insert-entry-toggle)
  
  ;; minibuffer 中输入时关闭中文输入法
  (add-hook 'minibuffer-setup-hook 'deactivate-input-method)
  )
