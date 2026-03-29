;; This file contains only use-package blocks.
;; All Tree-sitter grammars, libraries, and dependencies are guaranteed
;; to be installed and provided by Nix. No checks, conditions, or
;; installation logic should ever be added here.

(use-package eat :ensure t :defer t)

;; Cap’n Proto (regex-based, non–Tree-Sitter)
(use-package capnp-mode :mode ("\\.capnp\\’" . capnp-mode))

;; Aski (tree-sitter major mode from aski flake)
(use-package aski-ts-mode :mode ("\\.aski\\’" . aski-ts-mode))

(use-package chatgpt-shell)

(use-package apheleia)

(use-package caser)

(use-package sublimity)
(use-package sublimity-map)

(use-package
 ultra-scroll
 :init
 (setq
  scroll-conservatively 3
  scroll-margin 0)
 :config (ultra-scroll-mode 1))

(use-package telega)

(use-package envrc :config (envrc-global-mode))

(use-package go-translate)
(use-package google-translate)

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

(use-package nix-update)

(use-package justl)

(use-package json-mode)

(use-package
 yaml-pro
 :config
 (add-to-list 'auto-mode-alist '("\\.yaml\\'" . yaml-pro-ts-mode)))

(use-package haskell-mode)

(use-package tera-mode)

;; Non-working - requires an elisp package, like nix-ts-mode
(use-package
 treesit
 :config
 (define-derived-mode
  capnp-ts-mode
  prog-mode
  "Capnp-TS"
  (treesit-parser-create 'capnp)
  (treesit-major-mode-setup))

 (define-derived-mode
  proto-ts-mode
  prog-mode
  "Proto-TS"
  (treesit-parser-create 'proto)
  (treesit-major-mode-setup))

 (define-derived-mode
  cozo-ts-mode
  prog-mode
  "Cozo-TS"
  (setq-local comment-start "# ")
  (setq-local comment-end "")
  (setq-local treesit-font-lock-feature-list
              '((comment string)
                (keyword type)
                (builtin number constant operator)
                (variable function punctuation)))
  (setq-local treesit-font-lock-settings
              (treesit-font-lock-rules
               :language 'cozo
               :feature 'comment
               '((comment) @font-lock-comment-face)

               :language 'cozo
               :feature 'string
               '((string) @font-lock-string-face
                 (escape_sequence) @font-lock-escape-face)

               :language 'cozo
               :feature 'keyword
               '((command_name) @font-lock-keyword-face
                 (option_name) @font-lock-keyword-face
                 (inline_rule ":=" @font-lock-keyword-face)
                 (constant_rule "<-" @font-lock-keyword-face)
                 (fixed_rule "<~" @font-lock-keyword-face)
                 (negation "not" @font-lock-keyword-face)
                 (disjunction "or" @font-lock-keyword-face)
                 (multi_unification "in" @font-lock-keyword-face)
                 (conditional_expression "if" @font-lock-keyword-face)
                 (if_block "%if" @font-lock-keyword-face)
                 (if_block "%then" @font-lock-keyword-face)
                 (if_block "%else" @font-lock-keyword-face)
                 (if_block "%end" @font-lock-keyword-face)
                 (if_not_block "%if_not" @font-lock-keyword-face)
                 (if_not_block "%then" @font-lock-keyword-face)
                 (if_not_block "%else" @font-lock-keyword-face)
                 (if_not_block "%end" @font-lock-keyword-face)
                 (loop_block "%loop" @font-lock-keyword-face)
                 (loop_block "%end" @font-lock-keyword-face)
                 (loop_block "%mark" @font-lock-keyword-face)
                 (break_statement "%break" @font-lock-keyword-face)
                 (continue_statement "%continue" @font-lock-keyword-face)
                 (return_statement "%return" @font-lock-keyword-face)
                 (debug_statement "%debug" @font-lock-keyword-face)
                 (ignore_error_statement "%ignore_error" @font-lock-keyword-face)
                 (swap_statement "%swap" @font-lock-keyword-face))

               :language 'cozo
               :feature 'type
               '((stored_relation name: (identifier) @font-lock-type-face)
                 (search_apply name: (identifier) @font-lock-type-face)
                 (simple_type) @font-lock-type-face
                 (fixed_rule algorithm: (identifier) @font-lock-type-face))

               :language 'cozo
               :feature 'builtin
               '((system_command (command_name) @font-lock-builtin-face))

               :language 'cozo
               :feature 'number
               '((number) @font-lock-number-face)

               :language 'cozo
               :feature 'constant
               '((boolean) @font-lock-constant-face
                 (null) @font-lock-constant-face)

               :language 'cozo
               :feature 'operator
               '((operator) @font-lock-operator-face
                 (unification "=" @font-lock-operator-face)
                 (stored_relation "*" @font-lock-misc-punctuation-face)
                 (search_apply "~" @font-lock-misc-punctuation-face)
                 (rule_head "?" @font-lock-misc-punctuation-face)
                 (system_command "::" @font-lock-misc-punctuation-face))

               :language 'cozo
               :feature 'function
               '((rule_head name: (identifier) @font-lock-function-name-face)
                 (function_call name: (identifier) @font-lock-function-call-face)
                 (aggregation function: (identifier) @font-lock-function-call-face))

               :language 'cozo
               :feature 'variable
               '((parameter) @font-lock-variable-use-face
                 (named_binding key: (identifier) @font-lock-property-use-face)
                 (fixed_option key: (identifier) @font-lock-property-use-face)
                 (column_definition name: (identifier) @font-lock-property-use-face)
                 (data_field key: (identifier) @font-lock-property-use-face)
                 (object_pair key: (identifier) @font-lock-property-use-face))

               :language 'cozo
               :feature 'punctuation
               :override t
               '(["(" ")" "[" "]" "{" "}"] @font-lock-bracket-face
                 ["," ";" "=>"] @font-lock-delimiter-face)))
  (treesit-parser-create 'cozo)
  (treesit-major-mode-setup))

 (add-to-list 'auto-mode-alist '("\\.cozo\\'" . cozo-ts-mode))

 ;; Positional column faces for constant data rules
 (defface cozo-column-0
   '((((background dark))  :foreground "#e040a0")
     (((background light)) :foreground "#b03080"))
   "Column 0 — pink")
 (defface cozo-column-1
   '((((background dark))  :foreground "#00cc44")
     (((background light)) :foreground "#1a8a30"))
   "Column 1 — green")
 (defface cozo-column-2
   '((((background dark))  :foreground "#f5c000")
     (((background light)) :foreground "#b89000"))
   "Column 2 — yellow")
 (defface cozo-column-3
   '((((background dark))  :foreground "#ff8800")
     (((background light)) :foreground "#d06600"))
   "Column 3 — orange")
 (defface cozo-column-4
   '((((background dark))  :foreground "#cc44ff")
     (((background light)) :foreground "#9930cc"))
   "Column 4 — purple")
 (defface cozo-column-5
   '((((background dark))  :foreground "#ff0066")
     (((background light)) :foreground "#cc0044"))
   "Column 5 — red")
 (defface cozo-column-6
   '((((background dark))  :foreground "#bb44ee")
     (((background light)) :foreground "#8822bb"))
   "Column 6 — violet")
 (defface cozo-column-7
   '((((background dark))  :foreground "#ff5577")
     (((background light)) :foreground "#cc3355"))
   "Column 7 — salmon")

 (defvar cozo-column-faces
   [cozo-column-0 cozo-column-1 cozo-column-2 cozo-column-3
    cozo-column-4 cozo-column-5 cozo-column-6 cozo-column-7]
   "Cycling faces for positional column highlighting.")

 (defun cozo--color-children-by-position (node)
   "Apply column faces to named children of NODE by position."
   (let ((col 0))
     (dotimes (i (treesit-node-child-count node t))
       (let ((child (treesit-node-child node i t)))
         (unless (member (treesit-node-type child) '("," "[" "]" "(" ")" "?" "<-"))
           (when (< col (length cozo-column-faces))
             (put-text-property
              (treesit-node-start child)
              (treesit-node-end child)
              'face (aref cozo-column-faces col)))
           (setq col (1+ col)))))))

 (defun cozo--fontify-columns (start end)
   "Apply positional column colors to constant rule heads and data rows."
   (when (treesit-parser-list)
     (let ((root (treesit-buffer-root-node)))
       (dolist (cap (treesit-query-capture root
                      '((constant_rule) @rule) start end))
         (when (eq (car cap) 'rule)
           (let* ((node (cdr cap))
                  (head (treesit-node-child-by-field-name node "head"))
                  (body (treesit-node-child-by-field-name node "body")))
             ;; Color rule head variables positionally
             (when head (cozo--color-children-by-position head))
             ;; Color each data row positionally
             (when (and body (string= (treesit-node-type body) "list"))
               (dotimes (i (treesit-node-child-count body t))
                 (let ((row (treesit-node-child body i t)))
                   (when (string= (treesit-node-type row) "list")
                     (cozo--color-children-by-position row)))))))))))

 (add-hook 'cozo-ts-mode-hook
           (lambda () (jit-lock-register #'cozo--fontify-columns))))

(use-package
 rust-mode
 :custom (rust-mode-treesitter-derive t) (rust-format-on-save t))

(use-package magit-delta :hook (magit-mode . magit-delta-mode))

(use-package difftastic)

(use-package
 with-editor
 :hook (eshell-mode . with-editor-export-editor))

(use-package elisp-autofmt :before format-all)

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

;; Load ignis theme from darkman state at startup
(let ((theme-dir (expand-file-name ".config/emacs-ignis-themes" "~")))
  (when (file-directory-p theme-dir)
    (add-to-list 'custom-theme-load-path theme-dir)
    (let ((mode-file (expand-file-name "darkman/current-mode"
                       (or (getenv "XDG_STATE_HOME")
                           (expand-file-name ".local/state" "~")))))
      (when (file-readable-p mode-file)
        (let ((mode (string-trim (with-temp-buffer
                                   (insert-file-contents mode-file)
                                   (buffer-string)))))
          (pcase mode
            ("dark" (load-theme 'ignis-dark t))
            ("light" (load-theme 'ignis-light t))))))))

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
 :commands (format-all-mode format-all-buffer format-all-region-or-buffer)
 ;; markdown-mode is not prog-mode, so it needs its own hook.
 :hook
 ((prog-mode . format-all-mode)
  (markdown-mode . format-all-mode)
  (gfm-mode . format-all-mode))
 :init
 (setq format-all-formatters
       '(("Emacs Lisp" elisp-autofmt)
         ("Python" ruff)
         ("Shell" (shfmt "-i" "4" "-ci"))
         ("Markdown" mdformat)
         ("JSON" prettier "--parser" "json")
         ("YAML" prettier "--parser" "yaml")
         ("Clojure" zprint)))
 :config
 ;; Native Emacs Lisp formatter
 (define-format-all-formatter
  elisp-autofmt
  (:executable)
  (:install nil)
  (:languages "Emacs Lisp")
  (:features region)
  (:format
   (format-all--buffer-native
    'elisp-autofmt-mode
    (if region
        (lambda () (elisp-autofmt-region (car region) (cdr region)))
      (lambda () (elisp-autofmt-buffer))))))

 ;; Python formatter: Ruff (Black-compatible)
 ;; Ruff formatter is whole-buffer only; no region support.
 (define-format-all-formatter
  ruff
  (:executable "ruff")
  (:install nil)
  (:languages "Python")
  (:features)
  (:format
   ;; ruff format reads stdin with "-" and writes to stdout
   (format-all--buffer-easy executable "format" "-")))

 ;; External Markdown formatter: mdformat
 ;; Note: mdformat is whole-document formatting; region formatting is not supported here.
 (define-format-all-formatter
  mdformat
  (:executable "mdformat")
  (:install nil)
  (:languages "Markdown")
  (:features)
  (:format
   ;; mdformat reads stdin when given "-" and writes formatted markdown to stdout.
   (format-all--buffer-easy executable "--wrap" "80" "-"))))


;; ─────────────────────────────────────────────────────────────
;; Live evaluation & introspection helpers
;; ─────────────────────────────────────────────────────────────
;;
;; This group makes Emacs Lisp development feel immediate and
;; "notebook-like" by showing results inline, surfacing rich
;; documentation, and allowing asynchronous Org-babel blocks.

;; Eros: show evaluation results inline (like Jupyter cells)
;; ---------------------------------------------------------
;; When you run C-x C-e (eval-last-sexp) or C-u C-x C-e
;; in an Emacs-Lisp buffer, eros displays the result briefly
;; beside the expression instead of only echoing it.
;; Lightweight: adds one overlay and then removes it.
(use-package eros :ensure t :hook (emacs-lisp-mode . eros-mode))

;; Helpful: richer describe-commands
;; ---------------------------------
;; Replaces vanilla `describe-function`, `describe-variable`,
;; and `describe-key` with an interactive viewer that shows
;; source, references, call sites, and links to definitions.
;; Use:
;;   M-x describe-function  →  Helpful buffer with docs + code
(use-package
 helpful
 :ensure t
 :bind
 (([remap describe-function] . helpful-function)
  ([remap describe-variable] . helpful-variable)
  ([remap describe-key] . helpful-key)))

;; Eldoc-box: hover popups for documentation
;; -----------------------------------------
;; Extends Eldoc by showing docstrings and argument lists in
;; a floating child-frame near point.  Activates automatically
;; when editing Emacs Lisp so you can see symbol docs as you
;; type or hover.
(use-package
 eldoc-box
 :ensure t
 :hook (emacs-lisp-mode . eldoc-box-hover-mode))

;; Org-babel async: run Org source blocks asynchronously
;; -----------------------------------------------------
;; Allows Org-mode code blocks (e.g., #+BEGIN_SRC emacs-lisp)
;; to execute in the background without blocking the UI.
;; Results are inserted when finished, useful for long-running
;; snippets or API calls.
(use-package ob-async :ensure t :after org)
