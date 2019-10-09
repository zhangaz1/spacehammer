;;; spacehammer.el --- auxiliary Emacs helpers to be used with Spacehammer.
;;
;; Copyright (c) 2018-2019 Ag Ibragimov
;;
;; Author: Ag Ibragimov <agzam.ibragimov@gmail.com>
;; URL: https://github.com/spacehammer
;;
;;; License: GPLv3

(defun spacehammer/alert (message)
  "shows Hammerspoon's hs.alert popup with a MESSAGE"
  (when (and message (eq system-type 'darwin))
    (call-process
     (executable-find "hs")
     nil 0 nil "-c" (concat "hs.alert.show(\"" message "\", 1)"))))

(defun spacehammer/fix-frame ()
  "Fix Emacs frame. It may be necessary when screen size changes.

Sometimes zoom-frm functions would leave visible margins around the frame."
  (cond
   ((eq (frame-parameter nil 'fullscreen) 'fullboth)
    (progn
      (set-frame-parameter (selected-frame) 'fullscreen 'fullheight)
      (set-frame-parameter (selected-frame) 'fullscreen 'fullboth)))
   ((eq (frame-parameter nil 'fullscreen) 'maximized)
    (progn
      (set-frame-parameter (selected-frame) 'fullscreen 'fullwidth)
      (set-frame-parameter (selected-frame) 'fullscreen 'maximized)))))

(defun spacehammer/move-frame-one-display (direction)
  "Moves current Emacs frame to another display at given DIRECTION

DIRECTION - can be North, South, West, East"
  (let* ((hs (executable-find "hs"))
         (cmd (concat "hs.window.focusedWindow():moveOneScreen" direction "()")))
    (call-process hs nil 0 nil "-c" cmd)
    (spacehammer/fix-frame)))

(defun spacehammer/switch-to-app (pid)
  "Using third party tools tries to switch to the app with the given PID"
  (when (and pid (eq system-type 'darwin))
    (call-process (executable-find "hs") nil 0 nil "-c"
                  (concat "require(\"emacs\").switchToApp (\"" pid "\")"))))

(defvar spacehammer/edit-with-emacs-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") 'spacehammer/finish-edit-with-emacs)
    (define-key map (kbd "C-c C-k") 'spacehammer/cancel-edit-with-emacs)
    map))

(define-minor-mode spacehammer/edit-with-emacs-mode
  "Minor mode enabled on buffers opened by spacehammer/edit-by-emacs"
  :init-value nil
  :lighter " editwithemacs"
  :keymap spacehammer/edit-with-emacs-mode-map)

(defun spacehammer/edit-with-emacs (&optional pid title screen)
  "Edit anything with Emacs

PID is a pid of the app (the caller is responsible to set that right)
TITLE is a title of the window (the caller is responsible to set that right)"
  (setq systemwide-edit-previous-app-pid pid)
  (select-frame-by-name "edit")
  (set-frame-position nil 400 400)
  (set-frame-size nil 800 600 t)
  (let ((buffer (get-buffer-create (concat "*edit-with-emacs " title " *"))))
    (set-buffer-major-mode buffer)
    (unless (bound-and-true-p global-edit-with-emacs-mode)
      (global-edit-with-emacs-mode 1))
    (with-current-buffer buffer
      (spacemacs/copy-clipboard-to-whole-buffer)
      (spacemacs/evil-search-clear-highlight)
      (delete-other-windows)
      (spacemacs/toggle-visual-line-navigation-on)
      (markdown-mode)
      (spacehammer/edit-with-emacs-mode 1)
      (evil-insert 1))
    (switch-to-buffer buffer))
  (when (and pid (eq system-type 'darwin))
    (call-process
     (executable-find "hs") nil 0 nil "-c"
     (concat "require(\"emacs\").editWithEmacsCallback(\""
             pid "\",\"" title "\",\"" screen "\")"))))

(defun spacehammer/turn-on-edit-with-emacs-mode ()
  "Turn on `spacehammer/edit-with-emacs-mode' if the buffer derives from that mode"
  (when (string-match-p "*edit-with-emacs" (buffer-name (current-buffer)))
    (spacehammer/edit-with-emacs-mode t)))

(define-global-minor-mode global-edit-with-emacs-mode
  spacehammer/edit-with-emacs-mode spacehammer/turn-on-edit-with-emacs-mode)

(defvar systemwide-edit-previous-app-pid nil
  "Last app that invokes `spacehammer/edit-with-emacs'.")

(defun spacehammer/finish-edit-with-emacs ()
  (interactive)
  (spacemacs/copy-whole-buffer-to-clipboard)
  (kill-buffer)
  (delete-frame)
  (call-process (executable-find "hs") nil 0 nil "-c"
                (concat "require(\"emacs\").switchToAppAndPasteFromClipboard (\"" systemwide-edit-previous-app-pid "\")"))
  (setq systemwide-edit-previous-app-pid nil))

(defun spacehammer/cancel-edit-with-emacs ()
  (interactive)
  (kill-buffer)
  (delete-frame)
  (spacehammer/switch-to-app systemwide-edit-previous-app-pid)
  (setq systemwide-edit-previous-app-pid nil))

(provide 'spacehammer)

;;; spacehammer.el ends here