(in-package :compiler)

(defvar *toplevel-defun-stream* *standard-output*)
(defvar *literal-symbols*)
(defvar *defun-names*)

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

(defparameter *builtin-function-table*
  (let ((table (make-hash-table)))
    (setf (gethash (read-from-string "CL:SYMBOLP") table) (list "lisp.CL_symbolp" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%MAKE-SYMBOL") table)
            (list "lisp.CL_makeSymbol" (list 1)))
    (setf (gethash (read-from-string "CL:SYMBOL-PLIST") table)
            (list "lisp.CL_symbolPlist" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::PUT-SYMBOL-PLIST") table)
            (list "lisp.CL_setSymbolPlist" (list 2)))
    (setf (gethash (read-from-string "CL:BOUNDP") table) (list "lisp.CL_boundp" (list 1)))
    (setf (gethash (read-from-string "CL:FBOUNDP") table) (list "lisp.CL_fboundp" (list 1)))
    (setf (gethash (read-from-string "CL:SYMBOL-VALUE") table)
            (list "lisp.CL_symbolValue" (list 1)))
    (setf (gethash (read-from-string "CL:SYMBOL-FUNCTION") table)
            (list "lisp.CL_symbolFunction" (list 1)))
    (setf (gethash (read-from-string "CL:SET") table) (list "lisp.CL_set" (list 2)))
    (setf (gethash (read-from-string "CL:MAKUNBOUND") table) (list "lisp.CL_makunbound" (list 1)))
    (setf (gethash (read-from-string "CL:FMAKUNBOUND") table) (list "lisp.CL_fmakunbound" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%SYMBOL-NAME") table)
            (list "lisp.CL_symbolName" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::SYMBOL-PACKAGE-NAME") table)
            (list "lisp.CL_symbolPackage" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::FSET") table)
            (list "lisp.CL_setSymbolFunction" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::MAP-PACKAGE-SYMBOLS") table)
            (list "lisp.CL_mapPackageSymbols" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%PUT") table) (list "lisp.CL_put" (list 3)))
    (setf (gethash (read-from-string "CL:PACKAGEP") table) (list "lisp.CL_packagep" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%PACKAGE-NAME") table)
            (list "lisp.CL_packageName" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%PACKAGE-NICKNAMES") table)
            (list "lisp.CL_packageNicknames" (list 1)))
    (setf (gethash (read-from-string "CL:LIST-ALL-PACKAGES") table)
            (list "lisp.CL_listAllPackages" (list 0)))
    (setf (gethash (read-from-string "SYSTEM::INTERN") table) (list "lisp.CL_intern" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::FIND-SYMBOL") table)
            (list "lisp.CL_findSymbol" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::MAKE-PACKAGE") table)
            (list "lisp.CL_makePackage" (list 3)))
    (setf (gethash (read-from-string "CL:NUMBERP") table) (list "lisp.CL_numberp" (list 1)))
    (setf (gethash (read-from-string "CL:INTEGERP") table) (list "lisp.CL_integerp" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%ADD") table) (list "lisp.CL_add" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%SUB") table) (list "lisp.CL_sub" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%NEGATE") table) (list "lisp.CL_negate" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%MUL") table) (list "lisp.CL_mul" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%REM") table) (list "lisp.CL_rem" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%=") table) (list "lisp.CL_numberEqual" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%/=") table) (list "lisp.CL_numberNotEqual" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%>") table) (list "lisp.CL_greaterThan" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%<") table) (list "lisp.CL_lessThan" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%>=") table) (list "lisp.CL_greaterEqual" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%<=") table) (list "lisp.CL_lessEqual" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%FLOOR") table) (list "lisp.CL_floor" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%LOGAND") table) (list "lisp.CL_logand" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::APPLY") table) (list "lisp.CL_apply" (list 2 nil)))
    (setf (gethash (read-from-string "CL:FUNCTIONP") table) (list "lisp.CL_functionp" (list 1)))
    (setf (gethash (read-from-string "CL:CONSP") table) (list "lisp.CL_consp" (list 1)))
    (setf (gethash (read-from-string "CL:CONS") table) (list "lisp.CL_cons" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%CAR") table) (list "lisp.CL_car" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%CDR") table) (list "lisp.CL_cdr" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%RPLACA") table) (list "lisp.CL_rplaca" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%RPLACD") table) (list "lisp.CL_rplacd" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::JS-ARRAY-TO-LIST") table)
            (list "lisp.CL_jsArrayToList" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::LIST-TO-JS-ARRAY") table)
            (list "lisp.CL_listToJsArray" (list 1)))
    (setf (gethash (read-from-string "CL:VALUES") table) (list "lisp.CL_values" (list 0 nil)))
    (setf (gethash (read-from-string "SYSTEM::MULTIPLE-VALUE-CALL") table)
            (list "lisp.CL_multipleValueCall" (list nil)))
    (setf (gethash (read-from-string "SYSTEM::MAKE-STRUCTURE") table)
            (list "lisp.CL_makeStructure" (list 1 nil)))
    (setf (gethash (read-from-string "SYSTEM::%COPY-STRUCTURE") table)
            (list "lisp.CL_copyStructure" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::STRUCTURE-P") table)
            (list "lisp.CL_structurep" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%STRUCTURE-NAME") table)
            (list "lisp.CL_structureName" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%STRUCTURE-SLOT-COUNT") table)
            (list "lisp.CL_structureSlotCount" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%STRUCTURE-REF") table)
            (list "lisp.CL_structureRef" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::%STRUCTURE-SET") table)
            (list "lisp.CL_structureSet" (list 3)))
    (setf (gethash (read-from-string "CL:EQ") table) (list "lisp.CL_eq" (list 2)))
    (setf (gethash (read-from-string "SYSTEM::ERROR") table) (list "lisp.CL_error" (list nil)))
    (setf (gethash (read-from-string "CL:CHARACTERP") table) (list "lisp.CL_characterp" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%CODE-CHAR") table)
            (list "lisp.CL_codeChar" (list 1)))
    (setf (gethash (read-from-string "SYSTEM::%CHAR-CODE") table)
            (list "lisp.CL_charCode" (list 1)))
    (setf (gethash (read-from-string "FFI::INSTANCEOF") table)
            (list "lisp.CL_instanceof" (list nil)))
    table))

(defparameter *emitter-table* (make-hash-table))

(defun to-js-identier (value &optional prefix)
  (flet ((f (c)
           (or (cdr (assoc c *character-map*))
               (string c))))
    (with-output-to-string (out)
      (when prefix (write-string prefix out))
      (map nil (lambda (c)
                 (write-string (f c) out))
           (princ-to-string value)))))

(defun to-js-local-var (symbol)
  (to-js-identier symbol "L_"))

(defun to-js-function-var (symbol)
  (to-js-identier symbol "F_"))

(defun symbol-to-js-value (symbol)
  (or (gethash symbol *literal-symbols*)
      (setf (gethash symbol *literal-symbols*)
            (genvar "G_"))))

(let ((i 0))
  (defun gen-temporary-js-var (&optional (prefix "TMP_"))
    (format nil "~A~D" prefix (incf i))))

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

(defun pass2-form (form)
  (cond ((ir-return-value-p form)
         (princ "return ")
         (unless (ir-multiple-values-p form)
           (princ "lisp.values1("))
         (pass2 form)
         (unless (ir-multiple-values-p form)
           (princ ")"))
         (write-line ";"))
        (t
         (pass2 form)
         (write-line ";"))))

(defun pass2-forms (forms)
  (do ((ir* forms (rest ir*)))
      ((null (rest ir*))
       (pass2-form (first ir*)))
    (pass2 (first ir*))
    (format t ";~%")))

(defun pass2-enter (return-value-p)
  (if return-value-p
      (write-line "(function() {")
      (write-line "{")))

(defun pass2-exit (return-value-p)
  (if return-value-p
      (write-string "})()")
      (write-line "}")))

(defmacro def-emit (op (ir) &body body)
  (let ((name (gensym)))
    `(progn
       (defun ,name (,ir)
         (declare (ignorable ir))
         ,@body)
       ,@(mapcar (lambda (op)
                   `(setf (gethash ',op *emitter-table*) ',name))
                 (if (consp op) op (list op))))))

(defun parse-string (string)
  (with-output-to-string (s)
    (write-char #\[ s)
    (let ((len (length string)))
      (do ((i 0 (1+ i)))
          ((>= i len))
        (princ (char-code (aref string i)) s)
        (when (< (1+ i) len)
          (write-string ", " s))))
    (write-char #\] s)))

(defun emit-literal (x)
  (cond ((null x)
         (princ "lisp.S_nil"))
        ((symbolp x)
         (princ (symbol-to-js-value x)))
        ((stringp x)
         (format t "CL_SYSTEM_JS_STRING_TO_ARRAY(lisp.codeArrayToString(~A))" (parse-string x)))
        ((numberp x)
         (princ x))
        ((characterp x)
         (format t "lisp.makeCharacter(~D)" (char-code x)))
        ((consp x)
         (princ "lisp.makeCons(")
         (emit-literal (car x))
         (princ ", ")
         (emit-literal (cdr x))
         (princ ")"))
        ((vectorp x)
         (write-string "CL_COMMON_LISP_VECTOR")
         (if (zerop (length x))
             (write-string "(")
             (dotimes (i (length x))
               (if (zerop i)
                   (write-string "(")
                   (write-string ","))
               (emit-literal (aref x i))))
         (write-string ")"))
        (t
         (error "unexpected literal: ~S" x)))
  (values))

(def-emit const (ir)
  (emit-literal (ir-arg1 ir)))

(def-emit lref (ir)
  (let ((binding (ir-arg1 ir)))
    (ecase (binding-type binding)
      ((:function)
       (princ (to-js-function-var (binding-name binding))))
      ((:variable)
       (princ (to-js-local-var (binding-value (ir-arg1 ir))))))))

(def-emit gref (ir)
  (let ((ident (symbol-to-js-value (ir-arg1 ir))))
    (format t "lisp.symbolValue(~A)" ident)))

(def-emit (lset gset) (ir)
  (when (ir-return-value-p ir)
    (write-string "("))
  (cond ((eq 'lset (ir-op ir))
         (format t "~A = " (to-js-local-var (binding-value (ir-arg1 ir))))
         (pass2 (ir-arg2 ir)))
        (t
         (let ((ident (symbol-to-js-value (ir-arg1 ir))))
           (format t "lisp.setSymbolValue(~A, " ident))
         (pass2 (ir-arg2 ir))
         (write-string ")")))
  (when (ir-return-value-p ir)
    (write-string ")")))

(def-emit if (ir)
  (pass2-enter (ir-return-value-p ir))
  (write-string "if (")
  (pass2 (ir-arg1 ir))
  (format t " !== lisp.S_nil) {~%")
  (pass2-form (ir-arg2 ir))
  (format t "} else {~%")
  (pass2-form (ir-arg3 ir))
  (format t "}")
  (pass2-exit (ir-return-value-p ir)))

(def-emit progn (ir)
  (pass2-enter (ir-return-value-p ir))
  (pass2-forms (ir-arg1 ir))
  (pass2-exit (ir-return-value-p ir)))

(defun emit-check-arguments (name parsed-lambda-list)
  (let ((min (parsed-lambda-list-min parsed-lambda-list))
        (max (parsed-lambda-list-max parsed-lambda-list)))
    (cond ((null max)
           (format t "if (arguments.length < ~D) {~%" min))
          ((= min max)
           (format t "if (arguments.length !== ~D) {~%" min))
          (t
           (format t "if (arguments.length < ~D || ~D < arguments.length) {~%" min max)))
    (format t "lisp.argumentsError(lisp.intern('~A'), arguments.length);~%" name)
    (write-line "}")))

(defmacro with-emit-paren (&body body)
  `(progn
     (write-string "(")
     ,@body
     (write-string ")")))

(defmacro emit-try-finally (try finally)
  `(progn
     (write-line "try {")
     ,try
     (write-line "} finally {")
     ,finally
     (write-line "}")))

(defmacro emit-try-catch (((err) &body catch)
                          &body try)
  `(progn
     (write-line "try {")
     ,@try
     (format t "} catch (~A) {" ,err)
     ,@catch
     (write-line "}")))

(defmacro with-unwind-special-vars (form unwind-code)
  (let ((unwind-code-var (gensym)))
    `(let ((,unwind-code-var ,unwind-code))
       (if (string= ,unwind-code-var "")
           ,form
           (emit-try-finally ,form (write-string ,unwind-code-var))))))

(defun emit-unwind-var (var stream)
  (when (eq :special (binding-type var))
    (let ((identier (symbol-to-js-value (binding-name var)))
          (save-var (to-js-identier (binding-value var) "SAVE_")))
      (format stream "~A.value = ~A;~%" identier save-var))))

(defun emit-declvar (var finally-stream)
  (ecase (binding-type var)
    ((:special)
     (let ((identier (symbol-to-js-value (binding-name var)))
           (save-var (to-js-identier (binding-value var) "SAVE_")))
       (format t "const ~A = ~A.value;~%" save-var identier)
       (format t "~A.value = " identier))
     (when finally-stream
       (emit-unwind-var var finally-stream)))
    ((:variable)
     (format t "let ~A = "
             (to-js-local-var (binding-value var))))
    ((:function)
     (format t "let ~A = "
             (to-js-function-var (binding-name var) ; !!!
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
          (format t "arguments.length > ~D ? arguments[~D] : " i i)
          (write-string "(")
          (pass2 value)
          (write-line ");")
          (when (third opt)
            (emit-declvar (third opt) finally-stream)
            (format t "(arguments.length > ~D ? lisp.S_t : lisp.S_nil);~%" i))
          (incf i)))
      (when (parsed-lambda-list-keys parsed-lambda-list)
        (let ((keyword-vars '()))
          (dolist (opt (parsed-lambda-list-keys parsed-lambda-list))
            (let ((var (first opt))
                  (value (second opt)))
              (let ((keyword-var (symbol-to-js-value (fourth opt)))
                    (supplied-var (to-js-identier (binding-value var) "SUPPLIED_")))
                (push keyword-var keyword-vars)
                (format t "let ~A;~%" supplied-var)
                (let ((loop-var (gen-temporary-js-var)))
                  (emit-for (loop-var i "arguments.length" 2)
                    (format t "if (arguments[~D] === ~A) {~%" loop-var keyword-var)
                    (format t "~A = arguments[~D+1];~%" supplied-var loop-var)
                    (write-line "break;")
                    (write-line "}")))
                (emit-declvar var finally-stream)
                (format t "~A !== undefined ? ~A : " supplied-var supplied-var)
                (write-string "(")
                (pass2 value)
                (write-line ");")
                (when (third opt)
                  (emit-declvar (third opt) finally-stream)
                  (format t "(~A !== undefined ? lisp.S_t : lisp.S_nil);~%" supplied-var)))))
          (format t "if ((arguments.length - ~D) % 2 === 1)" i)
          (write-line "{ lisp.programError('odd number of &KEY arguments'); }")
          (when (and keyword-vars
                     (null (parsed-lambda-list-allow-other-keys parsed-lambda-list)))
            (let ((loop-var (gen-temporary-js-var)))
              (emit-for (loop-var i "arguments.length" 2)
                (write-string "if (")
                (do ((keyword-var* keyword-vars (rest keyword-var*)))
                    ((null keyword-var*))
                  (format t "arguments[~D] !== ~A" loop-var (first keyword-var*))
                  (when (rest keyword-var*)
                    (write-string " && ")))
                (format
                 t
                 ") { lisp.programError('Unknown &KEY argument: ' + arguments[~A].name); }~%"
                 loop-var))))))
      (let ((rest-var (parsed-lambda-list-rest-var parsed-lambda-list)))
        (when rest-var
          (emit-declvar rest-var finally-stream)
          (format t "lisp.jsArrayToList(arguments, ~D);~%" i)
          (to-js-local-var (binding-value rest-var)))))))

(def-emit lambda (ir)
  (write-line "(function() {")
  (let ((name (ir-arg1 ir))
        (parsed-lambda-list (ir-arg2 ir)))
    (emit-check-arguments name parsed-lambda-list)
    (let ((finally-code
            (with-output-to-string (finally-stream)
              (emit-lambda-list parsed-lambda-list finally-stream))))
      (with-unwind-special-vars
          (pass2-forms (ir-arg3 ir))
        finally-code)))
  (write-string "})"))

(def-emit let (ir)
  (pass2-enter (ir-return-value-p ir))
  (dolist (binding (ir-arg1 ir))
    (emit-declvar (first binding) nil)
    (pass2 (second binding))
    (format t ";~%"))
  (with-unwind-special-vars
      (progn
        (pass2-forms (ir-arg2 ir)))
    (with-output-to-string (output)
      (when (ir-arg1 ir)
        (dolist (binding (reverse (ir-arg1 ir)))
          (emit-unwind-var (first binding) output)))))
  (pass2-exit (ir-return-value-p ir)))

(defun emit-call-args (args)
  (do ((arg* args (rest arg*)))
      ((null arg*))
    (pass2 (first arg*))
    (unless (null (rest arg*))
      (write-string ", ")))
  (write-string ")"))

(def-emit lcall (ir)
  (format t "~A(" (to-js-function-var (binding-name (ir-arg1 ir))))
  (emit-call-args (ir-arg2 ir)))

(defun call-default (ir)
  (format t "lisp.callFunctionWithCallStack(~A" (symbol-to-js-value (ir-arg1 ir)))
  (when (ir-arg2 ir)
    (write-string ", "))
  (emit-call-args (ir-arg2 ir)))

(defun call-builtin-using-list-spec (ir builtin)
  (flet ((gen (name)
           (format t "~A(" name)
           (emit-call-args (ir-arg2 ir))))
    (let ((nargs (length (ir-arg2 ir))))
      (destructuring-bind (name (&optional min (max min))) builtin
        (cond ((or (null min) (= min 0) (null max))
               (gen name))
              ((eql min max)
               (if (= nargs min)
                   (gen name)
                   (call-default ir)))
              ((or (null max) (= max 0))
               (if (<= min nargs)
                   (gen name)
                   (call-default ir)))
              (t
               (if (<= min nargs max)
                   (gen name)
                   (call-default ir))))))))

(def-emit call (ir)
  (let ((symbol (ir-arg1 ir)))
    (let ((builtin (gethash symbol *builtin-function-table*)))
      (cond ((null builtin)
             (call-default ir))
            ((consp builtin)
             (call-builtin-using-list-spec ir builtin))
            ((stringp builtin)
             (format t "~A(" builtin)
             (emit-call-args (ir-arg2 ir)))
            (t
             (funcall builtin ir))))))

(def-emit unwind-protect (ir)
  (pass2-enter (ir-return-value-p ir))
  (emit-try-finally
   (pass2 (ir-arg1 ir))
   (pass2 (ir-arg2 ir)))
  (pass2-exit (ir-return-value-p ir)))

(def-emit block (ir)
  (pass2-enter t)
  (let ((name (ir-arg1 ir))
        (error-var (genvar "E_")))
    (emit-try-catch
        ((error-var)
         (format t "if (~A instanceof lisp.BlockValue && ~A.name === ~A) { return ~A.value; }~%"
                 error-var
                 error-var
                 (symbol-to-js-value (binding-name name))
                 error-var)
         (format t "else { throw ~A; }~%" error-var))
      (pass2-forms (ir-arg2 ir))))
  (pass2-exit t))

(def-emit return-from (ir)
  (pass2-enter (ir-return-value-p ir))
  (let ((name (ir-arg1 ir)))
    (format t "throw new lisp.BlockValue(~A," (symbol-to-js-value (binding-name name)))
    (pass2 (ir-arg2 ir))
    (write-string ")"))
  (pass2-exit (ir-return-value-p ir)))

(def-emit tagbody (ir)
  (pass2-enter (ir-return-value-p ir))
  (let ((tag (genvar "V"))
        (err (genvar "E_")))
    (format t "let ~A = 0;~%" tag)
    (write-line "for (;;) {")
    (emit-try-catch
        ((err)
         (format t "if (~A instanceof lisp.TagValue && ~A.id === '~A') { ~A = ~A.index; }~%"
                 err
                 err
                 (ir-arg1 ir)
                 tag
                 err)
         (format t "else { throw ~A; }~%" err))
      (format t "switch(~A) {~%" tag)
      (dolist (tag-body (ir-arg2 ir))
        (destructuring-bind (tag . body) tag-body
          (format t "case ~D:~%" (tagbody-value-index tag))
          (pass2 body)))
      (write-line "}")
      (write-line "break;"))
    (write-line "}")
    (when (ir-return-value-p ir) (write-line "return lisp.S_nil;")))
  (pass2-exit (ir-return-value-p ir)))

(def-emit go (ir)
  (let ((tagbody-value (ir-arg2 ir)))
    (format t "throw new lisp.TagValue('~A', ~A)"
            (tagbody-value-id tagbody-value)
            (tagbody-value-index tagbody-value))))

(def-emit catch (ir)
  (pass2-enter t)
  (let ((err (genvar "E_"))
        (tag (genvar "TAG_")))
    (format t "let ~A = " tag)
    (pass2 (ir-arg1 ir))
    (write-line ";")
    (emit-try-catch
        ((err)
         (format t "if (~A instanceof lisp.CatchValue && ~A.symbol === ~A) { return ~A.value; }~%"
                 err err tag err)
         (format t "else { throw ~A; }~%" err))
      (pass2 (ir-arg2 ir))))
  (pass2-exit t))

(def-emit throw (ir)
  (pass2-enter (ir-return-value-p ir))
  (write-string "throw new lisp.CatchValue(")
  (pass2 (ir-arg1 ir))
  (write-string ", ")
  (pass2 (ir-arg2 ir))
  (write-string ")")
  (pass2-exit (ir-return-value-p ir)))

(def-emit *:%defun (ir)
  (let ((name (ir-arg1 ir))
        (function (ir-arg2 ir)))
    (let ((var (to-js-identier name
                               (if (symbol-package name)
                                   (format nil
                                           "CL_~A_"
                                           (to-js-identier (package-name (symbol-package name))))
                                   "CL_"))))
      (push var *defun-names*)
      (format *toplevel-defun-stream* "~A = " var)
      (let ((*standard-output* *toplevel-defun-stream*))
        (pass2 function)
        (write-char #\;))
      (let ((name-var (symbol-to-js-value name)))
        (write-line "(function() {")
        (format t "lisp.setSymbolFunction(~A, ~A);" name-var var)
        (format t "return ~A;" name-var)
        (write-string "})()")))))

(def-emit *:%defpackage (ir)
  (let ((name (ir-arg1 ir)))
    (format *toplevel-defun-stream* "lisp.defpackage('~A', {" name)
    (destructuring-bind (export-names use-package-names nicknames)
        (ir-arg2 ir)
      (let ((first t))
        (write-string "exportNames: [" *toplevel-defun-stream*)
        (dolist (name export-names)
          (if first
              (setq first nil)
              (write-string ", " *toplevel-defun-stream*))
          (format *toplevel-defun-stream* "'~A'" name))
        (write-string "]" *toplevel-defun-stream*))
      (write-string ", " *toplevel-defun-stream*)
      (let ((first t))
        (write-string "usePackageNames: [" *toplevel-defun-stream*)
        (dolist (name use-package-names)
          (if first
              (setq first nil)
              (write-string ", " *toplevel-defun-stream*))
          (format *toplevel-defun-stream* "'~A'" name))
        (write-string "]" *toplevel-defun-stream*))
      (write-string ", " *toplevel-defun-stream*)
      (let ((first t))
        (write-string "nicknames: [" *toplevel-defun-stream*)
        (dolist (name nicknames)
          (if first
              (setq first nil)
              (write-string ", " *toplevel-defun-stream*))
          (format *toplevel-defun-stream* "'~A'" name))
        (write-string "]" *toplevel-defun-stream*)))
    (write-line "});" *toplevel-defun-stream*)
    (format t "lisp.ensurePackage('~A')" name)))

(def-emit *:%in-package (ir)
  (let ((name (ir-arg1 ir)))
    (format t "lisp.changeCurrentPackage('~A')" name)))

(defun emit-ref (args)
  (destructuring-bind (object . keys) args
    (if (ir-p object)
        (pass2 object)
        (write-string object))
    (when keys
      (write-string "."))
    (do ((keys keys (rest keys)))
        ((null keys))
      (write-string (to-js-identier (first keys)))
      (when (rest keys)
        (write-string ".")))))

(def-emit ffi:ref (ir)
  (emit-ref (ir-arg1 ir)))

(def-emit ffi:set (ir)
  (with-emit-paren
    (pass2 (ir-arg1 ir))
    (write-string " = ")
    (pass2 (ir-arg2 ir))))

(defun pass2-convert-var (var)
  (if (stringp var)
      (to-js-identier var)
      (with-output-to-string (*standard-output*)
        (emit-ref (ir-arg1 var)))))

;; TODO: これは使えない位置があるはずだけどエラーチェックをしていない
(def-emit ffi:var (ir)
  (write-string "var ")
  (do ((vars (ir-arg1 ir) (rest vars)))
      ((null vars))
    (write-string (pass2-convert-var (first vars)))
    (when (rest vars)
      (write-string ", ")))
  (write-line ";"))

(def-emit ffi:typeof (ir)
  (with-emit-paren
    (write-string "typeof ")
    (pass2 (ir-arg1 ir))))

(def-emit ffi:new (ir)
  (with-emit-paren
    (write-string "new ")
    (pass2 (ir-arg1 ir))
    (write-string "(")
    (emit-call-args (ir-arg2 ir))))

(def-emit ffi:aget (ir)
  (with-emit-paren
    (with-emit-paren
      (pass2 (ir-arg1 ir)))
    (dolist (index (ir-arg2 ir))
      (write-string "[")
      (pass2 index)
      (write-string "]"))))

(def-emit js-call (ir)
  (emit-ref (ir-arg1 ir))
  (write-string "(")
  (emit-call-args (ir-arg2 ir)))

(defun pass2 (ir)
  (funcall (gethash (ir-op ir) *emitter-table*) ir))

(defun pass2-toplevel-1 (ir)
  (pass2 (make-ir 'progn nil nil (list ir))))

(defun emit-initialize-vars ()
  (maphash (lambda (symbol ident)
             (declare (ignore symbol))
             (format t "let ~A;~%" ident))
           *literal-symbols*)
  (dolist (name *defun-names*)
    (format t "let ~A;~%" name)))

(defun emit-initialize-symbols ()
  (maphash (lambda (symbol ident)
             (if (symbol-package symbol)
                 (format t "~A = lisp.intern('~A', '~A');~%"
                         ident
                         symbol
                         (package-name (symbol-package symbol)))
                 (format t "~A = lisp.makeSymbol(\"~A\");" ident symbol)))
           *literal-symbols*))

(defun pass2-toplevel (ir)
  (let ((*literal-symbols* (make-hash-table))
        (*defun-names* '())
        (*genvar-counter* 0))
    (let* ((*toplevel-defun-stream* (make-string-output-stream))
           (output (with-output-to-string (*standard-output*)
                     (pass2-toplevel-1 ir))))
      (emit-initialize-vars)
      (write-string (get-output-stream-string *toplevel-defun-stream*))
      (emit-initialize-symbols)
      (write-string output)))
  (values))

(defun pass2-toplevel-forms (ir-forms)
  (let ((*literal-symbols* (make-hash-table))
        (*defun-names* '())
        (*genvar-counter* 0))
    (let* ((*toplevel-defun-stream* (make-string-output-stream))
           (output (with-output-to-string (*standard-output*)
                     (emit-try-catch (("err")
                                      (write-line "CL_COMMON_LISP_FINISH_OUTPUT();")
                                      (write-line "console.log(err);"))
                       (dolist (ir ir-forms)
                         (pass2-toplevel-1 ir))
                       (write-line "CL_COMMON_LISP_FINISH_OUTPUT();")))))
      (emit-initialize-vars)
      (write-string (get-output-stream-string *toplevel-defun-stream*))
      (emit-initialize-symbols)
      (write-string output))))
