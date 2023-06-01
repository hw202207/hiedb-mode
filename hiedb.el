;;; hiedb.el --- Use hiedb code navigation and information

;; Copyright (C) 2022 James King

;; Author: James King <james@agentultra.com>
;; Version: 0.1
;; Keywords: haskell

;;; Commentary:

;; This package provides a minor-mode front end to hiedb for querying
;; Haskell code.

;;; Code:

(eval-when-compile (require 'subr-x))

(defcustom hiedb-command "hiedb"
  "Path to the hiedb executable."
  :type 'string
  :group 'hiedb-mode)

(defcustom hiedb-dbfile ".hiedb"
  "Path to the generated hiedb."
  :type 'string
  :group 'hiedb-mode)

(defcustom hiedb-hiefiles ".hiefiles"
  "Path to the hie files."
  :type 'string
  :group 'hiedb-mode)

(defcustom hiedb-project-root nil
  "Path to project source root."
  :type 'string
  :group 'hiedb-mode)

;;;###autoload
(define-minor-mode hiedb-mode
  "A minor mode for querying hiedb."
  :init-value nil
  :lighter " hie-mode"
  :keymap '(("\C-c\C-dr" . hiedb-interactive-refs)
            ("\C-c\C-dt" . hiedb-interactive-types)
            ("\C-c\C-dd" . hiedb-interactive-defs)
            ("\C-c\C-d\i" . hiedb-interactive-info)
            ("\C-c\C-d\s" . hiedb-interactive-reindex)
            ("\C-c\C-dT" . hiedb-interactive-type-def)
            ("\C-c\C-dN" . hiedb-interactive-name-def)
            )
  )

;; Interactive functions

;;;###autoload
(defun hiedb-interactive-refs ()
  "Query hiedb for references of symbol at point."
  (interactive)
  (let ((module (hiedb-module-from-path)))
    (hiedb-query-point-refs module (line-number-at-pos) (1+ (current-column)))))

;;;###autoload
(defun hiedb-interactive-types ()
  "Query hiedb type of symbol at point."
  (interactive)
  (let ((module (hiedb-module-from-path)))
    (hiedb-query-point-types module (line-number-at-pos) (1+ (current-column)))))

(defun hiedb-interactive-type-def ()
  "Look up definition of type."
  (interactive)
  (let ((value (read-string "Type name: ")))
    (hiedb-def-command "type-def" value)
    ))

(defun hiedb-interactive-name-def ()
  "Look up definition of type."
  (interactive)
  (let ((value (read-string "Constructor name: ")))
    (hiedb-def-command "name-def" value)
    ))


;;;###autoload
(defun hiedb-interactive-defs ()
  "Query hiedb definition of symbol at point."
  (interactive)
  (let ((module (hiedb-module-from-path)))
    (hiedb-query-point-defs module (line-number-at-pos) (1+ (current-column)))))

;;;###autoload
(defun hiedb-interactive-info ()
  "Query hiedb information on symbol at point."
  (interactive)
  (let ((module (hiedb-module-from-path)))
    (hiedb-query-point-info module (line-number-at-pos) (1+ (current-column)))))

;;;###autoload
(defun hiedb-interactive-reindex ()
  "Query hiedb information on symbol at point."
  (interactive)
  (hiedb-reindex))

;; Shell commands for calling out to hiedb.

(defun hiedb-query-point-refs (mod sline scol)
  "Query hiedb point-refs of MOD at SLINE SCOL."
  (call-hiedb "point-refs" mod sline scol))

(defun hiedb-query-point-types (mod sline scol)
  "Query type at point in MOD at SLINE SCOL."
  (call-hiedb "point-types" mod sline scol))

(defun hiedb-query-point-defs (mod sline scol)
  "Query defintions at SLINE SCOL in MOD."
  (call-hiedb "point-defs" mod sline scol))

(defun hiedb-query-point-info (mod sline scol)
  "Query symbol information at SLINE SCOL in MOD."
  (call-hiedb "point-info" mod sline scol))

(defun call-hiedb (cmd mod sline scol)
  (message (format "%s -D %s %s %s %d %d"
                   hiedb-command
                   hiedb-dbfile
                   cmd mod sline scol))
  (let*
      ((log-buffer (get-buffer-create "*hiedb*")))
    (set-buffer log-buffer)
    (read-only-mode -1)
    (with-current-buffer log-buffer
      (erase-buffer)
      (call-process hiedb-command nil t t
                    "-D" hiedb-dbfile cmd
                    mod (format "%d" sline) (format "%d" scol)))
    (read-only-mode 1)
    (display-buffer log-buffer
                    '(display-buffer-pop-up-window . ((side . top)
                                                      (window-height . 5)
                                                      (mode . (special-mode))
                                                      )))
    ))

(defun hiedb-def-command (defCmdName nameInput)
  (let*
      ((log-buffer (get-buffer-create "*hiedb*")))
    (message (format "%s -D %s %s %s"
                     hiedb-command
                     hiedb-dbfile
                     defCmdName
                     nameInput))
    (set-buffer log-buffer)
    (read-only-mode -1)
    (with-current-buffer log-buffer
      (erase-buffer)
      (make-process :name (format "%s %s" "hiedb" defCmdName)
                    :buffer log-buffer
                    :command (list hiedb-command "-D" hiedb-dbfile defCmdName nameInput)
                    :stderr log-buffer))
    (read-only-mode 1)
    (display-buffer log-buffer
                    '(display-buffer-pop-up-window . ((side . top)
                                                      (window-height . 5)
                                                      (mode . (special-mode))
                                                      )))))

(defun hiedb-reindex ()
  (let*
      ((log-buffer (get-buffer-create "*hiedb*")))
    (message (format "%s -D -%s index %s"
                     hiedb-command
                     hiedb-dbfile
                     hiedb-hiefiles))
    (set-buffer log-buffer)
    (read-only-mode -1)
    (with-current-buffer log-buffer
      (erase-buffer)
      (make-process :name "reindex hiedb"
                    :buffer log-buffer
                    :command (list hiedb-command "-D" hiedb-dbfile "index" hiedb-hiefiles)
                    :stderr log-buffer))
    (read-only-mode 1)
    (display-buffer log-buffer
                    '(display-buffer-pop-up-window . ((side . top)
                                                      (window-height . 5)
                                                      (mode . (special-mode))
                                                      )))))

;; Utilities

(defun hiedb-module-from-path ()
  "Get the module name from the buffer file path."
  (let ((s (buffer-string)))
    (if (string-match "^module \\([^ \n]+\\)" s)
        (match-string 1 s)
      (buffer-file-name))))

(provide 'hiedb)
;;; hiedb.el ends here
