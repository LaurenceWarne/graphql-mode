;;; graphql.el --- An Emacs mode for GraphQL         -*- lexical-binding: t; -*-

;; Copyright (C) 2016  David Vazquez Pua

;; Author: David Vazquez Pua <davazp@gmail.com>
;; Keywords: languages

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; 

;;; Code:

(require 'newcomment)
(require 'json)
(require 'url)

(defvar graphql-url
  nil)

(defun graphql--query (query)
  "Send QUERY to the server at `graphql-url' and return the
response from the server."
  (let ((url-request-method "POST")
        (url (format "%s/?query=%s" graphql-url (url-encode-url query))))
    (with-current-buffer (url-retrieve-synchronously url t)
      (goto-char (point-min))
      (search-forward "\n\n")
      (buffer-substring (point) (point-max)))))

(defun graphql-beginning-of-query ()
  "Move the point to the beginning of the current query."
  (interactive)
  (while (and (> (point) (point-min))
              (or (> (current-indentation) 0)
                  (> (car (syntax-ppss)) 0)))
    (forward-line -1)))

(defun graphql-end-of-query ()
  "Move the point to the end of the current query."
  (interactive)
  (while (and (< (point) (point-max))
              (or (> (current-indentation) 0)
                  (> (car (syntax-ppss)) 0)))
    (forward-line 1)))

(defun graphql-current-query ()
  (let ((start
         (save-excursion
           (graphql-beginning-of-query)
           (point)))
        (end
         (save-excursion
           (graphql-end-of-query)
           (point))))
    (buffer-substring-no-properties start end)))


(defun graphql-send-query ()
  (interactive)
  (unless graphql-url
    (setq graphql-url (read-string "GraphQL URL: " )))
  (let* ((query (graphql-current-query))
         (response (graphql--query query)))
     (with-current-buffer-window
     "*GraphQL*" 'display-buffer-pop-up-window nil
     (erase-buffer)
     (json-mode)
     (insert response)
     (json-pretty-print-buffer))))



(defvar graphql-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") 'graphql-send-query)
    map))

(defvar graphql-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?\# "<" st)
    (modify-syntax-entry ?\n ">" st)
    st))


(defun graphql-indent-line ()
  (let ((position (point))
        (indent-pos))
    (save-excursion
      (let ((level (car (syntax-ppss (point-at-bol)))))

        ;; Handle closing pairs
        (when (looking-at "\\s-*\\s)")
          (setq level (1- level)))

        (indent-line-to (* 2 level))
        (setq indent-pos (point))))

    (when (< position indent-pos)
      (goto-char indent-pos))))


(defvar graphql-definition-regex
  (concat "\\(" (regexp-opt '("type" "input" "interface" "fragment" "query")) "\\)"
          "[[:space:]]+\\(\\w+\\)"))

(defvar graphql-builtin-types
  '("Int" "Float" "String" "Boolean" "ID"))

(defvar graphql-constants
  '("true" "false" "null"))

(defvar graphql-font-lock-keywords
  `(
    ;; Type definition
    ("\\(type\\)[[:space:]]+\\(\\w+\\)"
     (1 font-lock-keyword-face)
     (2 font-lock-function-name-face)
     ("[[:space:]]+\\(implements\\)\\(?:[[:space:]]+\\(\\w+\\)\\)?"
      nil nil
      (1 font-lock-keyword-face)
      (2 font-lock-function-name-face)))

    ;; Definitions
    (,graphql-definition-regex
     (1 font-lock-keyword-face)
     (2 font-lock-function-name-face))
    
    ;; Constants
    (,(regexp-opt graphql-constants) . font-lock-constant-face)
    ;; Built-in scalar types
    (,(regexp-opt graphql-builtin-types) . font-lock-type-face)
    ;; Directives
    ("@\\w+" . font-lock-keyword-face)
    ;; Variables
    ("\\$\\w+" . font-lock-variable-name-face)))


(define-derived-mode graphql-mode prog-mode "GraphQL"
  ""
  (make-variable-buffer-local 'graphql-url)
  (setq-local comment-start "# ")
  (setq-local comment-start-skip "#+[\t ]*")
  (setq-local indent-line-function 'graphql-indent-line)
  (setq font-lock-defaults
        (list 'graphql-font-lock-keywords
              nil
              nil
              nil))
  (setq imenu-generic-expression
        `((nil ,graphql-definition-regex 2))))

(add-to-list 'auto-mode-alist '("\\.graphql\\'" . graphql-mode))


(provide 'graphql)
;;; graphql.el ends here
