(in-package :common-lisp)

(defun canonicalize-direct-slot (direct-slot-spec)
  (let ((result `(:name ,(if (consp direct-slot-spec)
                             (car direct-slot-spec)
                             direct-slot-spec)))
        (others '()))
    (do ((plist (if (consp direct-slot-spec) (cdr direct-slot-spec) nil)
                (cddr plist)))
        ((null plist))
      (let ((key (car plist))
            (value (cadr plist)))
        (case key
          (:initform
           (setq result
                 (append result `(:initform ,value
                                  :initfunction (lambda () ,value)))))
          (:initarg
           (setf (getf result :initargs)
                 (nconc (getf result :initargs)
                        (list value))))
          ((:reader :writer :accessor)
           (case key
             ((:accessor :reader)
              (setf (getf result :readers)
                    (nconc (getf result :readers)
                           (list value)))))
           (case key
             ((:accessor :writer)
              (setf (getf result :writer)
                    (nconc (getf result :writer)
                           (list value))))))
          (:documentation
           (setf (getf result :documentation) value))
          (otherwise
           (setf (getf others key)
                 (nconc (getf others key) (list value)))))))
    (do ((plist others (cddr plist)))
        ((null plist))
      (let ((k (car plist))
            (v (cadr plist)))
        (setf (getf result k)
              (if (null (cdr v))
                  (car v)
                  v))))
    (do ((plist result (cddr plist)))
        ((null plist))
      (setf (car plist) (list 'quote (car plist)))
      (setf (cadr plist) (list 'quote (cadr plist))))
    result))

(defun canonicalize-direct-slot-specs (direct-slot-specs)
  (mapcar #'canonicalize-direct-slot direct-slot-specs))

(defun canonicalize-defclass-options (options)
  (mapcar (lambda (elt)
            (let ((key (car elt))
                  (rest (cdr elt)))
              (when (eq key :default-initargs)
                (setq key :direct-default-initargs))
              (cons key
                    (case key
                      (:direct-default-initargs
                       (let ((initargs '()))
                         (do ((plist rest (cddr plist)))
                             ((null plist))
                           (push `(list ,(car plist)
                                        ,(cadr plist)
                                        (lambda () ,@(cadr plist)))
                                 initargs))
                         (nreverse initargs)))
                      ((:metaclass :documentation)
                       (list 'quote (car rest)))
                      (otherwise
                       (list 'quote rest))))))
          options))

(defun ensure-class-using-class (class name &key direct-default-initargs direct-slots
                                                 direct-superclasses name metaclass)
  )

(defun ensure-class (name &rest args)
  (apply #'ensure-class-using-class (find-class name nil) name args))

(defmacro defclass (name direct-super-classes direct-slot-specs &rest options)
  `(ensure-class ',name
                 :direct-super-classes ',direct-subclasses
                 :direct-slots ,(canonicalize-direct-slot-specs direct-slot-specs)
                 ,@(canonicalize-defclass-options options)))
