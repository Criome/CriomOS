(use-package apheleia)

(use-package caser)

(use-package sublimity)
(use-package sublimity-map)

(use-package telega)

(use-package envrc :config (envrc-global-mode))

(use-package
 nov
 :config
 (add-to-list 'auto-mode-alist '("\\.epub\\'" . nov-mode)))

(use-package
 org-remark
 :custom
 (org-remark-notes-file-name "~/git/wiki/remark.org")
 (org-remark-source-file-name #'abbreviate-file-name))

(use-package
 eglot
 :custom (eglot-extend-to-xref t)
 :config
 (add-to-list 'eglot-server-programs '(nix-ts-mode . ("nil"))))

(use-package
 flycheck-eglot
 :ensure t
 :after (flycheck eglot)
 :config (global-flycheck-eglot-mode 1))

(use-package highlight-indentation)

(use-package
 nix-ts-mode
 :config
 (add-to-list 'auto-mode-alist '("\\.nix\\'" . nix-ts-mode)))

(use-package nixfmt :hook (nix-ts-mode . nixfmt-on-save-mode))

(use-package justl)

(use-package json-mode)

(use-package
 yaml-pro
 :config
 (add-to-list 'auto-mode-alist '("\\.yaml\\'" . yaml-pro-ts-mode)))

(use-package haskell-mode)

(use-package tera-mode)

(use-package
 rust-mode
 :custom (rust-mode-treesitter-derive t) (rust-format-on-save t))

(use-package magit-delta :hook (magit-mode . magit-delta-mode))

(use-package difftastic)

(use-package
 with-editor
 :hook (eshell-mode . with-editor-export-editor))

(use-package elisp-autofmt)

(use-package ssh-deploy)

(use-package
 org-roam
 :after (md-roam)
 :config (org-roam-db-autosync-mode 1)
 :custom
 (org-roam-v2-ack t)
 (org-roam-directory "~/git/wiki")
 (org-roam-file-extensions '("md" "org"))
 (org-roam-capture-templates
  (list
   '("d" "default" plain ""
     :target
     (file+head
      "%<%Y%m%d%H%M%S-${title}>.md"
      "---\ntitle: ${title}\nid: %<%Y-%m-%dT%H%M%S>\ncategory: \n---\n")
     :unnarrowed t))))

(use-package md-roam :config (md-roam-mode 1))

(use-package password-store)

(use-package base16-theme)

;; Clojure
(use-package clojure-ts-mode :custom (clojure-ts-ensure-grammars nil))

(use-package
 flycheck-clj-kondo
 :hook
 ((clojure-ts-mode clojurescript-ts-mode clojurec-ts-mode)
  .
  flycheck-mode)
 :config
 (progn
   (flycheck-clj-kondo--define-checker
    clj-kondo-clj "clj" clojure-ts-mode "--cache")
   (flycheck-clj-kondo--define-checker
    clj-kondo-cljs "cljs" clojurescript-ts-mode "--cache")
   (flycheck-clj-kondo--define-checker
    clj-kondo-cljc "cljc" clojurec-ts-mode "--cache")
   (flycheck-clj-kondo--define-checker
    clj-kondo-edn "edn" clojure-ts-mode "--cache")
   (dolist (element
            '(clj-kondo-clj
              clj-kondo-cljs clj-kondo-cljc clj-kondo-edn))
     (add-to-list 'flycheck-checkers element))))

; TODO figure out why this double entry is needed
(use-package flycheck-clj-kondo)

(use-package cider)
(use-package zprint-format)

(use-package
 company
 :hook
 ((lisp-mode nix-ts-mode emacs-lisp-mode clojure-ts-mode rust-ts-mode)
  . company-mode))

(use-package dockerfile-mode :mode "Dockerfile")

(use-package
 xah-fly-keys
 :config
 (defun xfk-mentci-modify ()
   (xah-fly--define-keys
    xah-fly-command-map
    '(("~" . nil)
      (":" . nil)
      ("SPC" . xah-fly-leader-key-map)
      ("DEL" . xah-fly-leader-key-map)
      ("'" . xah-reformat-lines)
      ("," . xah-shrink-whitespaces)
      ("-" . xah-cycle-hyphen--space)
      ("." . backward-kill-word)
      (";" . xah-comment-dwim)
      ("/" . hippie-expand)
      ("\\" . nil)
      ("=" . nil)
      ("[" . xah-backward-punct)
      ("]" . xah-forward-punct)
      ("`" . other-frame)
      ("1" . xah-extend-selection)
      ("2" . xah-select-line)
      ("3" . delete-other-windows)
      ("4" . split-window-below)
      ("5" . delete-char)
      ("6" . xah-select-block)
      ("7" . xah-select-line)
      ("8" . xah-extend-selection)
      ("9" . xah-select-text-in-quote)
      ("0" . xah-pop-local-mark-ring)
      ("a" . execute-extended-command)
      ("b" . phi-search)
      ("K" . phi-search-backward) ; HAK - xfk bog (shift'ed keys)
      ("c" . previous-line)
      ("d" . xah-beginning-of-line-or-block)
      ("e" . xah-delete-left-char-or-selection)
      ("f" . undo)
      ("g" . backward-word)
      ("h" . backward-char)
      ("i" . xah-delete-current-text-block)
      ("j" . xah-copy-line-or-region)
      ("k" . xah-paste-or-paste-previous)
      ("l" . xah-insert-space-before)
      ("m" . xah-backward-left-bracket)
      ("n" . forward-char)
      ("o" . open-line)
      ("p" . kill-word)
      ("q" . xah-cut-line-or-region)
      ("r" . forward-word)
      ("s" . xah-end-of-line-or-block)
      ("t" . next-line)
      ("u" . xah-fly-insert-mode-activate)
      ("v" . xah-forward-right-bracket)
      ("w" . xah-next-window-or-frame)
      ("x" . consult-imenu)
      ("y" . set-mark-command)
      ("z" . xah-goto-matching-bracket)))
   (xah-fly--define-keys
    (define-prefix-command 'navigate-filesystem)
    '(("b" . consult-line)
      ("d" . deadgrep)
      ("h" . consult-buffer)
      ("t" . find-file-in-project)
      ("c" . projectile-switch-project)
      ("n" . magit-find-file)
      ("s" . find-file)))
   (xah-fly--define-keys
    (define-prefix-command 'multi-cursors)
    '(("b" . mc/mark-all-in-region-regexp)
      ("d" . mc/mark-all-like-this)
      ("h" . mc/mark-previous-like-this)
      ("c" . mc/cycle-backward)
      ("t" . mc/cycle-forward)
      ("n" . mc/mark-next-like-this)
      ("s" . mc/mark-all-dwim)
      ("g" . mc/skip-to-previous-like-this)
      ("r" . mc/skip-to-next-like-this)))
   (xah-fly--define-keys
    (define-prefix-command 'xah-fly-leader-key-map)
    '(("SPC" . xah-fly-insert-mode-activate)
      ("DEL" . xah-fly-insert-mode-activate)
      ("RET" . xah-fly-M-x)
      ("TAB" . xah-fly--tab-key-map)
      ("." . xah-fly-dot-keymap)
      ("'" . xah-fill-or-unfill)
      ("," . xah-fly-comma-keymap)
      ("-" . xah-show-formfeed-as-line)
      ("\\" . toggle-input-method)
      ("3" . delete-window)
      ("4" . split-window-right)
      ("5" . balance-windows)
      ("6" . xah-upcase-sentence)
      ("9" . ispell-word)
      ("a" . mark-whole-buffer)
      ("b" . end-of-buffer)
      ("c" . xah-fly-c-keymap)
      ("d" . beginning-of-buffer)
      ("e" . multi-cursors)
      ("f" . xah-search-current-word)
      ("g" . xah-close-current-buffer)
      ("h" . xah-fly-h-keymap)
      ("i" . kill-line)
      ("j" . xah-copy-all-or-region)
      ("k" . consult-yank-from-kill-ring)
      ("l" . recenter-top-bottom)
      ("m" . dired-jump)
      ("n" . xah-fly-n-keymap)
      ("o" . exchange-point-and-mark)
      ("p" . query-replace)
      ("q" . xah-cut-all-or-region)
      ("r" . xah-fly-r-keymap)
      ("s" . save-buffer)
      ("t" . xah-fly-t-keymap)
      ("u" . navigate-filesystem)
      ;; v
      ("w" . xah-fly-w-keymap)
      ("x" . xah-toggle-previous-letter-case)
      ;; z
      ("y" . xah-show-kill-ring))))
 (defun start-xah-fly-keys ()
   (xah-fly-keys 1)
   (xah-fly-keys-set-layout "colemak")
   (xfk-mentci-modify))
 (if (daemonp)
     (add-hook 'server-after-make-frame-hook 'start-xah-fly-keys)
   (start-xah-fly-keys))
 :custom (xah-fly-use-control-key nil))

(use-package multiple-cursors :custom (mc/always-run-for-all t))

(use-package
 auth-source-pass
 :config (auth-source-pass-enable)
 :custom (auth-sources '(password-store)))

(use-package phi-search)

(use-package poly-markdown)

(use-package which-key :config (which-key-mode))

(use-package deadgrep)

(use-package forge :after (magit))

(use-package code-review)

(use-package magit :config (put 'magit-clean 'disabled nil))

(use-package git-gutter :config (global-git-gutter-mode))

(use-package
 projectile
 :config (projectile-mode +1)
 :custom (projectile-project-search-path '("~/git/" "/git/")))

(use-package
 eshell-prompt-extras
 :config
 (with-eval-after-load "esh-opt"
   (autoload 'epe-theme-lambda "eshell-prompt-extras"))
 :custom
 (eshell-highlight-prompt nil)
 (eshell-prompt-function 'epe-theme-lambda))

(use-package lispy :hook ((emacs-lisp-mode lisp-mode) . lispy-mode))

(use-package
 adaptive-wrap
 :hook
 ((emacs-lisp-mode lisp-mode nix-ts-mode)
  .
  adaptive-wrap-prefix-mode))

(use-package
 transmission
 :custom
 (transmission-refresh-modes
  '(transmission-mode
    transmission-files-mode
    transmission-info-mode
    transmission-peers-mode)))

(use-package find-file-in-project :custom (ffip-use-rust-fd t))


(use-package git-link :custom (git-link-use-commit t))

(use-package
 flycheck
 :custom
 (flycheck-idle-change-delay 7)
 (flycheck-idle-buffer-switch-delay 49)
 (flycheck-check-syntax-automatically
  '(save idle-change mode-enabled)))

(use-package
 flycheck-guile
 :custom (geiser-default-implementation 'guile))

(use-package notmuch :commands notmuch)
(use-package notmuch-maildir)

(use-package unicode-fonts :config (unicode-fonts-setup))


(use-package ghq :commands ghq)

(use-package shfmt :hook (sh-mode . shfmt-on-save-mode))

(use-package sly)
(use-package sly-macrostep)
(use-package sly-asdf)
(use-package sly-quicklisp)

(use-package tokei)

(use-package visual-regexp-steroids)

(use-package
 zoxide
 :hook
 ((find-file projectile-after-switch-project) . zoxide-add))

(use-package ztree)

(use-package
 format-all
 :commands format-all-mode
 :hook (prog-mode . format-all-mode)
 :config
 (define-format-all-formatter
  elisp-autofmt
  (:executable)
  (:install "M-x package-install elisp-autofmt")
  (:languages "Emacs Lisp")
  (:features region)
  (:format
   (format-all--buffer-native
    'elisp-autofmt-mode
    (if region
        (lambda () (elisp-autofmt-region (car region) (cdr region)))
      (lambda () (elisp-autofmt-region (point-min) (point-max)))))))
 :custom
 (format-all-formatters
  (push '("Emacs Lisp" elisp-autofmt) format-all-default-formatters)))
