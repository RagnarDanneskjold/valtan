(in-package :compiler)

(defvar *literal-symbols*)

(defparameter *character-map*
  '((#\! . "BANG")       
    (#\" . "QUOTATION")  
    (#\# . "HASH")       
    (#\$ . "DOLLAR")     
    (#\% . "PERCENT")    
    (#\& . "AMPERSAND")  
    (#\' . "QUOTE")      
    (#\( . "LPAREN")     
    (#\) . "RPAREN")     
    (#\* . "STAR")       
    (#\+ . "PLUS")       
    (#\, . "COMMA")      
    (#\- . "_")          
    (#\. . "DOT")        
    (#\/ . "SLASH")      
    (#\: . "COLON")      
    (#\; . "SEMICOLON")  
    (#\< . "LESS")       
    (#\= . "EQUAL")      
    (#\> . "GREATER")    
    (#\? . "QUESTION")   
    (#\space . "SPACE")  
    (#\@ . "AT")         
    (#\[ . "LBRACKET")   
    (#\\ . "BACKSLASH")  
    (#\] . "RBRACKET")   
    (#\^ . "CARET")      
    (#\_ . "__")         
    (#\` . "BACKQUOTE")  
    (#\{ . "LBRACE")     
    (#\| . "PIPE")       
    (#\} . "RBRACE")     
    (#\~ . "TILDE")
    (#\newline . "NEWLINE")
    (#\return . "RETURN")
    (#\backspace . "BACK")
    (#\page . "PAGE")
    (#\tab . "TAB")))

(defparameter *emitter-table* (make-hash-table))

(defun symbol-to-js-identier (symbol)
  (flet ((f (c)
           (or (cdr (assoc c *character-map*))
               (string c))))
    (with-output-to-string (out)
      (map nil (lambda (c)
                 (write-string (f c) out))
           (string symbol)))))

(defun const-to-js-literal (value)
  (typecase value
    (null "lisp.nilValue")
    (symbol
     (or (gethash value *literal-symbols*)
         (setf (gethash value *literal-symbols*)
               (symbol-to-js-identier value))))
    (otherwise (princ-to-string value))))

(defun js-call (name &rest args)
  (format nil "~A(~{~A~^,~})" name args))

(defun pass2-form (form return-value-p)
  (when return-value-p
    (princ "return "))
  (pass2 form return-value-p)
  (format t ";~%"))

(defun pass2-forms (forms return-value-p)
  (do ((ir* forms (rest ir*)))
      ((null (rest ir*))
       (pass2-form (first ir*) return-value-p))
    (pass2 (first ir*) nil)
    (format t ";~%")))

(defmacro def-emit (op (ir return-value-p) &body body)
  (let ((name (gensym)))
    `(progn
       (defun ,name (,ir ,return-value-p)
         (declare (ignorable ir return-value-p))
         ,@body)
       ,@(mapcar (lambda (op)
                   `(setf (gethash ',op *emitter-table*) ',name))
                 (if (consp op) op (list op))))))

(def-emit const (ir return-value-p)
  (princ (const-to-js-literal (ir-arg1 ir))))

(def-emit lref (ir return-value-p)
  (princ (symbol-to-js-identier (ir-arg1 ir))))

(def-emit gref (ir return-value-p)
  (princ (js-call "lisp.global_variable" (format nil "\"~A\"" (ir-arg1 ir)))))

(def-emit (lset gset) (ir return-value-p)
  (when return-value-p
    (write-string "("))
  (cond ((eq 'lset (ir-op ir))
         (format t "~A = " (symbol-to-js-identier (ir-arg1 ir)))
         (pass2 (ir-arg2 ir) t))
        (t
         (format t "lisp.set_global_value(\"~A\", " (ir-arg1 ir))
         (pass2 (ir-arg2 ir) t)
         (write-string ")")))
  (when return-value-p
    (write-string ")")))

(def-emit if (ir return-value-p)
  (when return-value-p
    (format t "(function() {~%"))
  (write-string "if (")
  (pass2 (ir-arg1 ir) t)
  (format t " !== lisp.nilValue) {~%")
  (pass2-form (ir-arg2 ir) return-value-p)
  (format t "} else {~%")
  (pass2-form (ir-arg3 ir) return-value-p)
  (format t "}")
  (if return-value-p
      (write-string "})()")
      (terpri)))

(def-emit progn (ir return-value-p)
  (when return-value-p
    (format t "(function() {~%"))
  (pass2-forms (ir-arg1 ir) return-value-p)
  (when return-value-p
    (format t "})()")))

(def-emit lambda (ir return-value-p)
  (format t "(function(~{~A~^, ~}) {~%" (ir-arg1 ir))
  (pass2-forms (ir-arg2 ir) t)
  (format t "})"))

(def-emit let (ir return-value-p)
  (if return-value-p
      (format t "(function() {~%")
      (format t "{~%"))
  (dolist (binding (ir-arg1 ir))
    (format t "let ~A = " (symbol-to-js-identier (first binding)))
    (pass2 (second binding) t)
    (format t ";~%"))
  (pass2-forms (ir-arg2 ir) return-value-p)
  (if return-value-p
      (format t "})()")
      (format t "}~%")))

(def-emit call (ir return-value-p)
  (let ((symbol (ir-arg1 ir)))
    (format t "lisp.call_function(~S, ~S"
            (package-name (symbol-package symbol))
            (symbol-name symbol))
    (dolist (arg (ir-arg2 ir))
      (write-string ", ")
      (pass2 arg t))
    (write-string ")")))

(defun pass2 (ir return-value-p)
  (funcall (gethash (ir-op ir) *emitter-table*)
           ir
           return-value-p))

(defun pass2-toplevel (form)
  (let ((*literal-symbols* (make-hash-table)))
    (let ((output
            (with-output-to-string (*standard-output*)
              (pass2 (pass1-toplevel form) nil))))
      (maphash (lambda (symbol ident)
                 (format t "~A = intern('~A');~%" ident symbol))
               *literal-symbols*)
      (write-string output))))