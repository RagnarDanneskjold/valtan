(defpackage :valtan-host.system
  (:use :cl)
  (:export :system-name
           :system-pathname
           :system-pathnames
           :system-enable-profile
           :system-depends-on
           :system-target
           :system-file-p
           :load-system
           :find-system
           :load-system-file
           :compute-system-precedence-list
           :system-to-pathname))
(in-package :valtan-host.system)

(defpackage :valtan-host.system-user (:use :cl))

(defparameter +valtan-core-system+ "valtan-core")
(defparameter *system-directories* (list (asdf:system-relative-pathname :valtan "./library/")))

(defvar *system-map* (make-hash-table :test 'equal))

(defstruct system
  name
  pathname
  (pathnames '())
  (enable-profile nil)
  (depends-on '())
  (target nil :type (member :node :browser nil)))

(defun ensure-system-package-exist ()
  (find-package :valtan-host.system-user))

(defun featurep (expr)
  (cond ((keywordp expr)
         (member expr *features*))
        ((not (consp expr))
         (error "invalid feature: ~S" expr))
        ((ecase (first expr)
           (:and
            (every #'featurep (rest expr)))
           (:or
            (some #'featurep (rest expr)))
           (:not
            (not (featurep (second expr)))))
         t)))

(defun parse-components (components system-name directory)
  (loop :for c :in components
        :for file :=
           (destructuring-bind (&key ((:file name)) (if-feature nil if-feature-p)) c
             (unless name
               (error "Illegal component: ~S" c))
             (let ((file
                     (probe-file
                      (make-pathname :name name
                                     :type "lisp"
                                     :directory directory))))
               (unless file
                 (error "~S not found for system ~S" name system-name))
               (when (or (not if-feature-p)
                         (featurep if-feature))
                 file)))
        :when file
        :collect file))

(defmacro valtan-host.system-user::defsystem
    (name &key (serial nil serial-p) depends-on components target &allow-other-keys)
  (check-type target (member :node :browser nil))
  (assert (or (not serial-p) (eq serial t)))
  `(setf (gethash ,(string name) *system-map*)
         (make-system :name ,(string name)
                      :pathname *load-pathname*
                      :depends-on ',(if (string= (string-downcase name) +valtan-core-system+)
                                        depends-on
                                        (cons +valtan-core-system+ depends-on))
                      :pathnames ',(parse-components components
                                                     name
                                                     (pathname-directory
                                                      *load-pathname*))
                      :target ,target)))

(defmacro with-system-env (() &body body)
  `(let ((*package* (ensure-system-package-exist))
         (*features* (adjoin :valtan *features*)))
     ,@body))

(defun load-system (pathname)
  (with-system-env ()
    (load pathname)))

(defun system-file-p (pathname)
  (or (equal (pathname-type pathname) "system")
      (equal (pathname-type pathname) "asd")))

(defun defsystem-form-p (form)
  (and (consp form)
       (symbolp (first form))
       (string-equal (first form) "defsystem")
       (<= 2 (length form))))

(defun lookup (system-file system-name)
  (with-open-file (in system-file)
    (with-system-env ()
      (loop :with eof := '#:eof
            :for form := (read in nil eof)
            :until (eq form eof)
            :do (when (and (defsystem-form-p form)
                           (string-equal (second form) system-name))
                  (return t))))))

(defun find-system-file (system-name)
  (labels ((ok (pathname)
             (when (and (system-file-p pathname)
                        (lookup pathname system-name))
               pathname))
           (f (directory)
             (or (some #'ok (uiop:directory-files directory))
                 (some #'f (uiop:subdirectories directory)))))
    (some #'f *system-directories*)))

(defun find-system (system-name &optional (errorp t))
  (let ((system-pathname (find-system-file system-name)))
    (cond (system-pathname
           (load-system system-pathname)
           (gethash (string-downcase system-name) *system-map*))
          (errorp
           (error "System ~S is not found" system-name)))))

(defun load-system-file (pathname)
  (load-system pathname)
  (gethash (pathname-name pathname) *system-map*))

(defun compute-system-precedence-list (system)
  (let ((seen (make-hash-table :test 'equal))
        (systems '()))
    (labels ((f (system)
               (unless (gethash (system-name system) seen)
                 (setf (gethash (system-name system) seen) t)
                 (dolist (system-name (system-depends-on system))
                   (f (find-system system-name)))
                 (push system systems))))
      (f system)
      (nreverse systems))))

(defun system-to-pathname (system)
  (make-pathname :directory (pathname-directory (system-pathname system))
                 :name (ppcre:regex-replace-all "/" (system-name system) "-slash-")
                 :type (pathname-type (system-pathname system))))
