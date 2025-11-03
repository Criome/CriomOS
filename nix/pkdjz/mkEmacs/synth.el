;;; crio-synth.el --- CriomOS dev loop helpers: GPTel + Superchat + Aidermacs -*- lexical-binding: t; -*-

;; This file configures:
;; - Copilot for inline completions
;; - GPTel for ad-hoc chat/refactor flows (Markdown-first)
;; - Superchat (Markdown chat interface atop GPTel) with lightweight memory
;; - Aidermacs (Emacs-native UI for Aider) — no vterm dependency

;; ─────────────────────────────────────────────────────────────
;; Core group & defaults
;; ─────────────────────────────────────────────────────────────

(defgroup crio/develop nil
  "CriomOS development loop helpers."
  :group 'tools
  :prefix "crio/")

(defcustom crio/aider-default-command
  "aider --model openai/gpt-5 --no-auto-commit"
  "Default aider command used by external scripts or shell invocations.
Note: Aidermacs does not use this directly; it manages Aider via its own backend."
  :type 'string
  :group 'crio/develop)

(defcustom crio/gptel-system-prompt
  "You are an expert NixOS, Emacs and systems programming pair-programmer."
  "System prompt supplied to GPTel helper commands."
  :type 'string
  :group 'crio/develop)

(defcustom crio/gptel-default-model 'gpt-5
  "Default model identifier used for GPTel sessions."
  :type 'symbol
  :group 'crio/develop)

(defun crio/gptel--read-api-key ()
  "Return API key strictly from OPENAI_API_KEY, auth-source(:host api.openai.com),
or pass entry 'openai/api-key'. Never use 'openapi/api-key'."
  (let* ((from-env (getenv "OPENAI_API_KEY"))
         (from-auth (ignore-errors
                      (auth-source-pick-first-password :host "api.openai.com")))
         (from-pass (ignore-errors
                      (auth-source-pass-get 'secret "openai/api-key")))
         ;; Detect the mistaken entry just to warn (but do NOT use it).
         (wrong-pass (ignore-errors
                       (auth-source-pass-get 'secret "openapi/api-key")))
         (key (or from-env from-auth from-pass)))
    (when (and wrong-pass (not key))
      (message "[gptel] Ignoring pass entry 'openapi/api-key' (wrong path)."))
    (unless (and key (stringp key) (> (length key) 0))
      (error "No API key. Set OPENAI_API_KEY, add to auth-source (:host api.openai.com), or create pass 'openai/api-key' (first line = secret)."))
    key))

;; ─────────────────────────────────────────────────────────────
;; Copilot
;; ─────────────────────────────────────────────────────────────

(use-package copilot
  :hook (prog-mode . copilot-mode)
  :bind (:map copilot-completion-map
              ("<tab>" . copilot-accept-completion)
              ("TAB" . copilot-accept-completion)
              ("C-<tab>" . copilot-accept-completion-by-word)
              ("M-<tab>" . copilot-accept-completion-by-line))
  :init
  ;; Disable completion if the buffer has changed since the last request.
  (setq copilot-disable-predicates '(copilot--buffer-changed-p))
  ;; Set a universal fallback indentation to prevent
  ;; “copilot--infer-indentation-offset found no mode-specific offset”
  ;; warnings in modes without an indent variable.
  (setq-default standard-indent 2)
  ;; Optionally, define common-mode offsets for clarity:
  (setq-default lisp-indent-offset 2
                python-indent-offset 4
                js-indent-level 2)
  :config
  ;; Ensure Copilot knows where Node.js lives.
  (setq copilot-node-executable (or (executable-find "node")
                                    copilot-node-executable))
  ;; Global quick-accept binding.
  (define-key global-map (kbd "C-c ]") #'copilot-accept-completion)
  ;; Unbind <tab> in Company mode so Copilot can use it.
  (with-eval-after-load 'company
    (define-key company-active-map (kbd "<tab>") nil)
    (define-key company-active-map (kbd "TAB") nil))
  ;; Bind Copilot toggle under Projectile map.
  (with-eval-after-load 'projectile
    (define-key projectile-command-map (kbd "]") #'copilot-mode)))

;; ─────────────────────────────────────────────────────────────
;; GPTel: chat, explain, rewrite — Markdown-first
;; ─────────────────────────────────────────────────────────────

(use-package gptel
  :commands (gptel gptel-send gptel-rewrite gptel-menu)
  :custom
  (gptel-default-mode 'markdown-mode)
  (gptel-use-curl t)
  :init
  (setq gptel-model crio/gptel-default-model)
  :config
  (let ((backend
         (gptel-make-openai "openai"
           :key #'crio/gptel--read-api-key
           :models '(gpt-5 gpt-5-mini gpt-5-nano gpt-4o gpt-4o-mini))))
    (setq gptel-backend backend)
    (setq gptel-default-backend backend))
  (defun crio/gptel--ensure-buffer (name)
    (let ((buffer (get-buffer-create name)))
      (with-current-buffer buffer
        (unless (derived-mode-p 'gptel-mode)
          (gptel-mode))
        (setq-local gptel-system-prompt crio/gptel-system-prompt)
        (setq-local gptel-model crio/gptel-default-model))
      buffer))
  (defun crio/gptel-explain-region (beg end)
    "Explain the region between BEG and END in a dedicated GPTel buffer."
    (interactive "r")
    (let* ((code (buffer-substring-no-properties beg end))
           (mode major-mode)
           (buffer (crio/gptel--ensure-buffer "*gptel-explain*"))
           (prompt (format "Explain the following %s code. Include intent, key APIs and follow-up ideas.\n\n```%s\n%s\n```"
                           mode mode code)))
      (gptel-request prompt
        :buffer buffer
        :system crio/gptel-system-prompt
        :model crio/gptel-default-model)))
  (defun crio/gptel-review-buffer ()
    "Summarise the current buffer using GPTel."
    (interactive)
    (crio/gptel-explain-region (point-min) (point-max)))
  (defun crio/gptel-refactor-region (beg end instruction)
    "Ask GPTel to rewrite region BEG..END according to INSTRUCTION."
    (interactive "r\nsRewrite instructions: ")
    (gptel-rewrite beg end instruction))
  (define-key global-map (kbd "C-c g g") #'gptel)
  (define-key global-map (kbd "C-c g e") #'crio/gptel-explain-region)
  (define-key global-map (kbd "C-c g b") #'crio/gptel-review-buffer)
  (define-key global-map (kbd "C-c g r") #'crio/gptel-refactor-region))

;; ─────────────────────────────────────────────────────────────
;; Superchat (Markdown chat interface built on GPTel)
;; ─────────────────────────────────────────────────────────────

(defcustom crio/superchat-data-directory "~/.emacs.d/superchat/"
  "Base directory where Superchat stores its sessions and memory files."
  :type 'directory
  :group 'crio/develop)

(defcustom crio/superchat-session-directory
  (expand-file-name "sessions" crio/superchat-data-directory)
  "Directory where Superchat saves Markdown chat sessions."
  :type 'directory
  :group 'crio/develop)

(defcustom crio/superchat-memory-file
  (expand-file-name "memory.org" crio/superchat-data-directory)
  "Org file where Superchat stores active memory entries."
  :type 'file
  :group 'crio/develop)

(defcustom crio/superchat-memory-archive-file
  (expand-file-name "memory-archive.org" crio/superchat-data-directory)
  "Org file where Superchat archives expired memory entries."
  :type 'file
  :group 'crio/develop)

(defcustom crio/superchat-context-message-count 12
  "Number of recent messages to include in Superchat context for continuity."
  :type 'integer
  :group 'crio/develop)

(defcustom crio/superchat-auto-save-sessions t
  "If non-nil, Superchat automatically saves all sessions to Markdown files."
  :type 'boolean
  :group 'crio/develop)

(defcustom crio/superchat-use-memory t
  "If non-nil, Superchat enables lightweight memory using Org files."
  :type 'boolean
  :group 'crio/develop)

(use-package superchat
  :after gptel
  :commands (superchat superchat-new-chat)
  :custom
  (superchat-default-mode 'markdown-mode)
  (superchat-data-directory crio/superchat-data-directory)
  (superchat-session-directory crio/superchat-session-directory)
  (superchat-context-message-count crio/superchat-context-message-count)
  (superchat-session-auto-save crio/superchat-auto-save-sessions)
  (superchat-backend gptel-default-backend)
  (superchat-model crio/gptel-default-model)
  (superchat-system-prompt crio/gptel-system-prompt)
  (superchat-memory-auto-capture-enabled crio/superchat-use-memory)
  (superchat-memory-file crio/superchat-memory-file)
  (superchat-memory-archive-file crio/superchat-memory-archive-file)
  :init
  (dolist (dir (list crio/superchat-data-directory crio/superchat-session-directory))
    (unless (file-directory-p dir)
      (make-directory dir t)))
  :config
  (define-key global-map (kbd "C-c g s") #'superchat)
  (define-key global-map (kbd "C-c g n") #'superchat-new-chat))

;; ─────────────────────────────────────────────────────────────
;; Aidermacs (Emacs-native UI for Aider) — no vterm required
;; ─────────────────────────────────────────────────────────────

(defgroup crio/aider nil
  "Aidermacs helpers and utilities."
  :group 'crio/develop
  :prefix "crio/aider-")

(defcustom crio/aider-config-file ".aider.conf.yml"
  "Repo-relative aider YAML configuration."
  :type 'string
  :group 'crio/aider)

(defcustom crio/aider-ignore-file ".aiderignore"
  "Repo-relative aider ignore file."
  :type 'string
  :group 'crio/aider)

(defun crio/aider--project-root ()
  "Try to find a project root using Projectile or built-in project.el."
  (cond
   ((and (boundp 'projectile-mode) projectile-mode (fboundp 'projectile-project-p)
         (projectile-project-p))
    (projectile-project-root))
   ((fboundp 'project-current)
    (when-let ((project (project-current)))
      (project-root project)))
   (t default-directory)))

(defun crio/aider-template-config ()
  "Create a sensible .aider.conf.yml if missing, then open it."
  (interactive)
  (let* ((root (or (crio/aider--project-root) default-directory))
         (path (expand-file-name crio/aider-config-file root)))
    (if (file-exists-p path)
        (find-file path)
      (with-temp-buffer
        (insert
         (concat
          "model: openai/gpt-5\n"
          "weak-model: openai/gpt-5-mini\n"
          "dark-mode: true\n"
          "auto-commits: true\n"
          "commit-prompt: >\n"
          "  Write a Conventional Commit message (max 1 line, imperative).\n"
          "  Summarize WHAT changed and WHY, referencing files when useful.\n"
          "  No trailing period.\n"
          "map-tokens: 4096\n"
          "think-tokens: 12000\n"
          "add-gitignore-files: false\n"))
        (write-file path))
      (find-file path))))

(defun crio/aider-template-ignore ()
  "Create a basic .aiderignore if missing, then open it."
  (interactive)
  (let* ((root (or (crio/aider--project-root) default-directory))
         (path (expand-file-name crio/aider-ignore-file root)))
    (if (file-exists-p path)
        (find-file path)
      (with-temp-buffer
        (insert "/*\n!lisp/**\n!src/**\n!flake.nix\n!flake.lock\n!README.md\n!LICENSE\n")
        (write-file path))
      (find-file path))))

(use-package aidermacs
  :ensure t
  :after gptel
  :bind (("C-c a a" . aidermacs-transient-menu)
         ("C-c a c" . crio/aider-template-config)
         ("C-c a i" . crio/aider-template-ignore))
  :custom
  (aidermacs-default-chat-mode 'architect)   ;; architect / code / ask
  (aidermacs-default-model "gpt-5"))

(provide 'crio-synth)
;;; crio-synth.el ends here
