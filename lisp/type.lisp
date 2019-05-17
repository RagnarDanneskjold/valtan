(in-package :common-lisp)

(defun typep (object type &optional environment)
  (declare (ignore environment))
  (case type
    ;; (list (listp object))
    ;; (cons (consp object))
    ;; (symbol (symbolp object))
    ;; (string (stringp object))
    ;; (hash-table (hash-table-p object))
    ;; (vector (vectorp object))
    ;; (array (arrayp object))
    ;; (integer (integerp object))
    ;; (numberp (numberp object))
    (otherwise
     (if (system::structure-p object)
         (eq (system::structure-name object)
             type)))))