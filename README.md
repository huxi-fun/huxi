# 呼吸中文输入法

版本： 2.0

作者： huxifun@sina.com

呼吸中文输入法是在 `Emacs` 和 `Vim/Neovim` 中使用的中文输入法，输入中文比较快捷方便，适合软件编程人员使用。 

**目录：** 

 - [1. 中文编码](#sec-1)
 - [2. Emacs版](#sec-2)
 - [3. Vim/Neovim版](#sec-3)
 - [4. 小小平台版](#sec-4)
 - [5. Android 手机版](#sec-5)

## 1. 中文编码<a id="sec-1"></a>

中文采用三码郑码，选取 3500 常用字，三码单字输入，简单快速。

详见 [三码郑码](https://www.yuque.com/smzm/zhengma/)

## 2. Emacs版<a id="sec-2"></a>

举例，先把 emacs 目录放到 `.emacs.d` 中，然后按照下边进行设置。

```emacs-lisp
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
```

快捷键

`M-SPC` 切换输入法

`C-,` 切换中英文标点

`C-e` 输入英文

`C-n` 选项下一页

`C-p` 选项上一页

`C-m` 输入字母

`C-c` 取消输入

`C-g` 取消当前输入，并切换到英文

`M-u` 删除已经输入的单词

`C-z` 删除选项中前一个字母

`SPC` 选择第一项


## 3. Vim/Neovim 版<a id="sec-5"></a>

详见 `vim` 目录。

## 4. 小小平台版<a id="sec-4"></a>

[Yong输入法 - 小小输入法](http://yong.dgod.net/)

支持Windows, Linux, Android。

复制 yong 目录。


## 5. Android 手机版<a id="sec-5"></a>

方法1: 安装 `Termux` ，再安装 Emacs 或 Vim，再按照上边的方法配置，同时使用 `Hacker’s Keyboard` 或 `AnySoftKeyboard` 键盘APP会方便些。

方法2: 直接使用 `Yong小小输入法` 手机APP，再复制 `yong` 目录中的内容到 `sdcard/yong` 目录下。

