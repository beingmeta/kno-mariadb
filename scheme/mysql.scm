;;; -*- Mode: Scheme; -*-

;;; Compatability for MYSQL module using MARIADB
;;; Note that if there is a compatible MSYQL module installed,
;;;  it may be preferred to this wrapper

(use-module 'mariadb)

(module-export! '{mysql/open mysql/refresh})

(define mysql/open mariadb/open)
(define mysql/refresh mariadb/refresh)
