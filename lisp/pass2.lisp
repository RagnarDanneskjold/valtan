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

(defparameter *var-counter* 0)

(defun gen-var (prefix)
  (format nil "~A~D" prefix (incf *var-counter*)))

(defun symbol-to-js-identier (symbol &optional prefix)
  (flet ((f (c)
           (or (cdr (assoc c *character-map*))
               (string c))))
    (with-output-to-string (out)
      (when prefix (write-string prefix out))
      (map nil (lambda (c)
                 (write-string (f c) out))
           (string symbol)))))

(defun symbol-to-js-local-var (symbol)
  (symbol-to-js-identier symbol "L_"))

(defun symbol-to-js-function-var (symbol)
  (symbol-to-js-identier symbol "F_"))

(defun symbol-to-js-global-var (symbol)
  (check-type symbol symbol)
  (or (gethash symbol *literal-symbols*)
      (setf (gethash symbol *literal-symbols*)
            (gen-var "G_"))))

(let ((i 0))
  (defun gen-temporary-js-var (&optional (prefix "TMP_"))
    (format nil "~A~D" prefix (incf i))))

(defun const-to-js-literal (value)
  (typecase value
    (null "lisp.nilValue")
    (symbol (symbol-to-js-global-var value))
    (otherwise (princ-to-string value))))

(defun %emit-for (loop-var start end step function)
  (write-string "for (let ")
  (write-string loop-var)
  (write-string " = ")
  (princ start)
  (write-string "; ")
  (write-string loop-var)
  (write-string " < ")
  (write-string end)
  (write-string "; ")
  (write-string loop-var)
  (if (= step 1)
      (write-string " ++")
      (progn
        (write-string " += ")
        (princ step)))
  (write-line ") {")
  (funcall function)
  (write-line "}"))

(defmacro emit-for ((loop-var start end step) &body body)
  `(%emit-for ,loop-var ,start ,end ,step (lambda () ,@body)))

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
  (let ((binding (ir-arg1 ir)))
    (ecase (binding-type binding)
      ((:function)
       (princ (symbol-to-js-function-var (binding-name binding))))
      ((:variable)
       (princ (symbol-to-js-local-var (binding-value (ir-arg1 ir))))))))

(def-emit gref (ir return-value-p)
  (let ((ident (symbol-to-js-global-var (ir-arg1 ir))))
    (format t "lisp.symbol_value(~A)" ident)))

(def-emit (lset gset) (ir return-value-p)
  (when return-value-p
    (write-string "("))
  (cond ((eq 'lset (ir-op ir))
         (format t "~A = " (symbol-to-js-local-var (binding-value (ir-arg1 ir))))
         (pass2 (ir-arg2 ir) t))
        (t
         (let ((ident (symbol-to-js-global-var (ir-arg1 ir))))
           (format t "lisp.set_symbol_value(~A, " ident))
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

(defun emit-check-arguments (parsed-lambda-list)
  (let ((min (parsed-lambda-list-min parsed-lambda-list))
        (max (parsed-lambda-list-max parsed-lambda-list)))
    (cond ((null max)
           (format t "if (arguments.length < ~D) {~%" min))
          ((= min max)
           (format t "if (arguments.length !== ~D) {~%" min))
          (t
           (format t "if (arguments.length < ~D || ~D < arguments.length) {~%" min max)))
    (write-line "throw new Error('invalid number of arguments');")
    (write-line "}")))

(defmacro emit-try-finally (try finally)
  `(progn
     (write-line "try {")
     ,try
     (write-line "} finally {")
     ,finally
     (write-line "}")))

(defmacro with-unwind-special-vars (form unwind-code)
  (let ((unwind-code-var (gensym)))
    `(let ((,unwind-code-var ,unwind-code))
       (if (string= ,unwind-code-var "")
           ,form
           (emit-try-finally ,form (write-string ,unwind-code-var))))))

(defun emit-declvar (var finally-stream)
  (ecase (binding-type var)
    ((:special)
     (let ((identier (symbol-to-js-global-var (binding-value var)))
           (save-var (symbol-to-js-identier (binding-value var) "SAVE_")))
       (format t "const ~A = ~A.value;~%" save-var identier)
       (format t "~A.value = " identier)
       (format finally-stream "~A.value = ~A;~%" identier save-var)))
    ((:variable)
     (format t "let ~A = "
             (symbol-to-js-local-var (binding-value var))))
    ((:function)
     (format t "let ~A = "
             (symbol-to-js-function-var (binding-name var) ; !!!
                                        )))))

(defun emit-lambda-list (parsed-lambda-list finally-stream)
  (flet ()
    (let ((i 0))
      (dolist (var (parsed-lambda-list-vars parsed-lambda-list))
        (emit-declvar var finally-stream)
        (format t "arguments[~D];~%" i)
        (incf i))
      (dolist (opt (parsed-lambda-list-optionals parsed-lambda-list))
        (let ((var (first opt))
              (value (second opt)))
          (emit-declvar var finally-stream)
          (format t "arguments[~D] || " i)
          (write-string "(")
          (pass2 value t)
          (write-line ");")
          (when (third opt)
            (emit-declvar (third opt) finally-stream)
            (format t "(arguments.length > ~D ? lisp.tValue : lisp.nilValue);~%" i))
          (incf i)))
      (when (parsed-lambda-list-keys parsed-lambda-list)
        (let ((keyword-vars '()))
          (dolist (opt (parsed-lambda-list-keys parsed-lambda-list))
            (let ((var (first opt))
                  (value (second opt)))
              (let ((keyword-var (symbol-to-js-global-var (fourth opt)))
                    (supplied-var (symbol-to-js-identier (binding-value var) "SUPPLIED_")))
                (push keyword-var keyword-vars)
                (format t "let ~A;~%" supplied-var)
                (let ((loop-var (gen-temporary-js-var)))
                  (emit-for (loop-var i "arguments.length" 2)
                    (format t "if (arguments[~D] === ~A) {~%" loop-var keyword-var)
                    (format t "~A = arguments[~D+1];~%" supplied-var loop-var)
                    (write-line "break;")
                    (write-line "}")))
                (emit-declvar var finally-stream)
                (format t "~A || " supplied-var)
                (write-string "(")
                (pass2 value t)
                (write-line ");")
                (when (third opt)
                  (emit-declvar (third opt) finally-stream)
                  (format t "(~A ? lisp.tValue : lisp.nilValue);~%" supplied-var)))))
          (format t "if ((arguments.length - ~D) % 2 === 1)" i)
          (write-line "{ throw new Error('odd number of &KEY arguments'); }")
          (when (and keyword-vars
                     (null (parsed-lambda-list-allow-other-keys parsed-lambda-list)))
            ;; TODO: &allow-other-keys
            (let ((loop-var (gen-temporary-js-var)))
              (emit-for (loop-var i "arguments.length" 2)
                (write-string "if (")
                (do ((keyword-var* keyword-vars (rest keyword-var*)))
                    ((null keyword-var*))
                  (format t "arguments[~D] !== ~A" loop-var (first keyword-var*))
                  (when (rest keyword-var*)
                    (write-string " && ")))
                (format t ") { throw new Error('Unknown &KEY argument: ' + arguments[~A].name); }~%" loop-var))))))
      (let ((rest-var (parsed-lambda-list-rest-var parsed-lambda-list)))
        (when rest-var
          (emit-declvar rest-var finally-stream)
          (format t "lisp.jsArrayToList(arguments.slice(~D));~%" i)
          (symbol-to-js-local-var (binding-value rest-var)))))))

(def-emit lambda (ir return-value-p)
  (let ((parsed-lambda-list (ir-arg1 ir)))
    (write-line "(function() {")
    (emit-check-arguments parsed-lambda-list)
    (let ((finally-code
            (with-output-to-string (finally-stream)
              (emit-lambda-list parsed-lambda-list finally-stream))))
      (with-unwind-special-vars
          (pass2-forms (ir-arg2 ir) t)
        finally-code))
    (format t "})")))

(def-emit let (ir return-value-p)
  (if return-value-p
      (format t "(function() {~%")
      (format t "{~%"))
  (let ((finally-stream (make-string-output-stream)))
    (dolist (binding (ir-arg1 ir))
      (emit-declvar (first binding) finally-stream)
      (pass2 (second binding) t)
      (format t ";~%"))
    (with-unwind-special-vars
        (progn
          (pass2-forms (ir-arg2 ir) return-value-p))
      (get-output-stream-string finally-stream))
    (if return-value-p
        (format t "})()")
        (format t "}~%"))))

(def-emit (call lcall) (ir return-value-p)
  (if (eq (ir-op ir) 'call)
      (let ((ident (symbol-to-js-global-var (ir-arg1 ir))))
        (format t "lisp.call_function(~A, " ident))
      (format t "~A(" (symbol-to-js-function-var (binding-name (ir-arg1 ir)))))
  (do ((arg* (ir-arg2 ir) (rest arg*)))
      ((null arg*))
    (pass2 (first arg*) t)
    (unless (null (rest arg*))
      (write-string ", ")))
  (write-string ")"))

(def-emit block (ir return-value-p)
  (format t "(function() {~%")
  (let ((name (ir-arg1 ir))
        (error-var (gentemp))) ; !!!
    (write-line "try {")
    (pass2-forms (ir-arg2 ir) return-value-p)
    (format t "} catch (~A) {~%" error-var)
    (format t "if (~A instanceof lisp.BlockValue && ~A.name === ~A) { return ~A.value; }~%"
            error-var
            error-var
            (symbol-to-js-global-var (binding-name name))
            error-var)
    (format t "else { throw ~A; }~%" error-var)
    (write-line "}"))
  (format t "})()"))

(def-emit return-from (ir return-value-p)
  (format t "(function() {~%")
  (let ((name (ir-arg1 ir)))
    (format t "throw new lisp.BlockValue(~A," (symbol-to-js-global-var (binding-name name)))
    (pass2 (ir-arg2 ir) t)
    (write-string ")"))
  (write-string "})();"))

(def-emit tagbody (ir return-value-p)
  (if return-value-p
      (format t "(function() {~%")
      (format t "{~%"))
  (let ((tag (gen-var "V"))
        (err (gen-var "E_")))
    (format t "let ~A = 0;~%" tag)
    (write-line "for (;;) {")
    (write-line "try {")
    (format t "switch(~A) {~%" tag)
    (dolist (tag-body (ir-arg2 ir))
      (destructuring-bind (tag . body) tag-body
        (defparameter $ body)
        (format t "case ~D:~%" (tagbody-value-index tag))
        (pass2 body nil)))
    (write-line "}")
    (write-line "break;")
    (format t "} catch (~A) {" err)
    (format t "if (~A instanceof lisp.TagValue && ~A.level === ~D) { ~A = ~A.index; }~%"
            err
            err
            (ir-arg1 ir)
            tag
            err)
    (format t "else { throw ~A; }" err)
    (write-line "}")
    (write-line "}"))
  (if return-value-p
      (format t "})()")
      (format t "}~%")))

(def-emit go (ir return-value-p)
  (let ((tagbody-value (ir-arg2 ir)))
    (format t "throw new lisp.TagValue(~A, ~A)"
            (tagbody-value-level tagbody-value)
            (tagbody-value-index tagbody-value))))

(defun pass2 (ir return-value-p)
  (funcall (gethash (ir-op ir) *emitter-table*)
           ir
           return-value-p))

(defun pass2-toplevel-1 (ir)
  (pass2 (make-ir 'progn (list ir)) nil))

(defun emit-initialize-symbols ()
  (maphash (lambda (symbol ident)
             (format t "let ~A = lisp.intern('~A', '~A');~%"
                     ident
                     symbol
                     (package-name (symbol-package symbol))))
           *literal-symbols*))

(defun pass2-toplevel (ir)
  (let ((*literal-symbols* (make-hash-table)))
    (let ((output (with-output-to-string (*standard-output*)
                    (pass2-toplevel-1 ir))))
      (emit-initialize-symbols)
      (write-string output)))
  (values))

(defun pass2-toplevel-forms (ir-forms)
  (let ((*literal-symbols* (make-hash-table)))
    (let ((output (with-output-to-string (*standard-output*)
                    (dolist (ir ir-forms)
                      (pass2-toplevel-1 ir)))))
      (emit-initialize-symbols)
      (write-string output))))
