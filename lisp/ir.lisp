(in-package :compiler)

(defun make-ir (op &rest args)
  (ecase (length args)
    (1 (vector op (first args)))
    (2 (vector op (first args) (second args)))
    (3 (vector op (first args) (second args) (third args)))))

(defun ir-op (ir) (aref ir 0))
(defun ir-arg1 (ir) (aref ir 1))
(defun ir-arg2 (ir) (aref ir 2))
(defun ir-arg3 (ir) (aref ir 3))