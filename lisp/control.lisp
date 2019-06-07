(in-package :common-lisp)

(defmacro return (&optional value)
  `(return-from nil ,value))

(defmacro cond (&rest clauses)
  (if (null clauses)
      nil
      (let ((clause (first clauses)))
        `(if ,(first clause)
             ,(if (null (rest clause))
                  t
                  `(progn ,@(rest clause)))
             (cond ,@(rest clauses))))))

(defmacro or (&rest forms)
  (if (null forms)
      nil
      (let ((value (gensym)))
        `(let ((,value ,(first forms)))
           (if ,value
               ,value
               (or ,@(rest forms)))))))

(defmacro and (&rest forms)
  (cond ((null forms))
        ((null (rest forms)) (first forms))
        (t `(if ,(first forms)
                (and ,@(rest forms))
                nil))))

(defmacro when (test &body forms)
  `(if ,test
       (progn ,@forms)))

(defmacro unless (test &body forms)
  `(if ,test
       nil
       (progn ,@forms)))

(defun not (x)
  (if x nil t))

(eval-when (:compile-toplevel)
  (defun gensyms (list)
    (mapcar (lambda (x)
              (declare (ignore x))
              (gensym))
            list))
  (defun !get-setf-expansion (place &optional environment)
    (declare (ignore environment))
    (let ((setf-expander nil))
      (cond ((and (consp place)
                  (setq setf-expander (get (first place) 'setf-expander)))
             (cond
               ((symbolp setf-expander)
                (let ((vars (gensyms (rest place)))
                      (store (gensym "STORE")))
                  (values vars
                          (rest place)
                          (list store)
                          `(,setf-expander ,@vars ,store)
                          `(,(first place) ,@vars))))
               ((consp setf-expander)
                (let ((vars (gensyms (rest place)))
                      (store (gensym "STORE"))
                      (fn (eval `(lambda ,(first setf-expander)
                                   (lambda ,@(rest setf-expander))))))
                  (values vars
                          (rest place)
                          (list store)
                          (funcall (apply fn vars) store)
                          `(,(first place) ,@vars))))
               ((functionp setf-expander)
                (funcall setf-expander (rest place)))))
            ;; TODO: マクロはホスト側で管理しているので
            ;; コンパイラ内の情報を参照する必要があるはず
            ;; ((and (consp place) (symbolp (first place)) (macro-function (first place)))
            ;;  (get-setf-expansion (macroexpand place)))
            (t
             (let ((store (gensym)))
               (values nil nil (list store) `(setq ,place ,store) place)))))))

(defmacro setf (&rest pairs)
  (labels ((setf-expand-1 (place value)
             (multiple-value-bind (vars forms store set access)
                 (!get-setf-expansion place)
               (declare (ignore access))
               `(let* (,@(mapcar #'list
                                 (append vars store)
                                 (append forms (list value))))
                  ,set)))
           (setf-expand (pairs)
             (cond ((endp pairs) nil)
                   ((endp (cdr pairs)) (error "Odd number of args to SETF."))
                   (t (cons (setf-expand-1 (first pairs) (second pairs))
                            (setf-expand (cddr pairs)))))))
    `(progn ,@(setf-expand pairs))))

(defmacro defsetf (access-fn &rest rest)
  ;; TODO: documentation文字列
  ;; TODO: restが単一のシンボルか関数ではないときの処理
  (check-type access-fn symbol)
  (cond ((and (first rest)
              (or (symbolp (first rest)) (functionp (first rest))))
         (setf (get access-fn 'setf-expander) (first rest))
         `(progn
            ;(setf (get ',access-fn 'setf-expander) ,(first rest))
            ',access-fn))
        (t
         (setf (get access-fn 'setf-expander) rest)
         `(progn
            ;(setf (get ',access-fn 'setf-expander) ',rest)
            ',access-fn))))

(defmacro define-setf-expander (access-fn lambda-list &body body)
  (unless (symbolp access-fn)
    (error "DEFINE-SETF-EXPANDER access-function name ~S is not a symbol." access-fn))
  (let ((g-rest (gensym)))
    (setf (get access-fn 'setf-expander)
          (eval `(lambda (,g-rest)
                   (destructuring-bind ,lambda-list ,g-rest ,@body))))
    `',access-fn
    #+(or)
    `(eval-when (#|:compile-toplevel :load-toplevel|# :execute)
       (setf (get ',access-fn 'setf-expander)
             (lambda (,g-rest)
               (destructuring-bind ,lambda-list ,g-rest ,@body)))
       ',access-fn)))

(defmacro define-modify-macro (name lambda-list function &optional (documentation nil documentation-p))
  (let ((update-form
          (do ((rest lambda-list (cdr rest))
               (vars '()))
              ((null rest)
               `(list ',function access-form ,@(nreverse vars)))
            (cond ((eq '&optional (car rest)))
                  ((eq '&rest (car rest))
                   (return `(list* ',function access-form ,@(nreverse vars) (cadr rest))))
                  ((symbolp (car rest))
                   (push (car rest) vars))
                  (t
                   (push (caar rest) vars))))))
    (let ((reference (gensym "REFERENCE")))
      `(defmacro ,name (,reference ,@lambda-list)
         ,(when documentation-p `(,documentation))
         (multiple-value-bind (vars values stores set-form access-form)
             (!get-setf-expansion ,reference)
           (list 'let*
                 (mapcar #'list
                         (append vars stores)
                         (append values (list ,update-form)))
                 set-form))))))

(define-modify-macro incf (&optional (n 1)) +)
(define-modify-macro decf (&optional (n 1)) -)

(defmacro psetq (&rest pairs)
  (when (oddp (length pairs))
    (error "Odd number of args to PSETQ."))
  (let ((gvars '())
        (vars '())
        (values '()))
    (do ((pairs* pairs (cddr pairs*)))
        ((null pairs*))
      (let ((var (first pairs*))
            (value (second pairs*)))
        (push var vars)
        (push value values)
        (push (gensym) gvars)))
    (setq gvars (nreverse gvars))
    (setq vars (nreverse vars))
    (setq values (nreverse values))
    `(let ,(mapcar #'list gvars values)
       ,@(mapcar (lambda (var gvar) `(setq ,var ,gvar))
                 vars gvars)
       nil)))

(defmacro do (varlist endlist &body body)
  (let ((g-start (gensym)))
    `(block nil
       (let ,(mapcar (lambda (var-spec)
                       `(,(first var-spec)
                         ,(second var-spec)))
                     varlist)
         (tagbody
           ,g-start
           (if ,(first endlist)
               (return (progn ,@(rest endlist)))
               (progn
                 (tagbody ,@body)
                 (psetq ,@(mapcan (lambda (var-spec)
                                    (if (cddr var-spec)
                                        `(,(first var-spec)
                                          ,(third var-spec))))
                                  varlist))
                 (go ,g-start))))))))

(defmacro dotimes ((var expr &optional result) &body body)
  (let ((g-expr (gensym)))
    `(let ((,g-expr ,expr))
       (do ((,var 0 (+ ,var 1)))
           ((>= ,var ,g-expr) ,result)
         ,@body))))

(defmacro dolist ((var expr &optional result) &body body)
  (let ((g-list (gensym))
        (g-start (gensym)))
    `(block nil
       (let ((,g-list ,expr))
         (tagbody
           ,g-start
           (unless (endp ,g-list)
             (let ((,var (car ,g-list)))
               (setq ,g-list (cdr ,g-list))
               (tagbody ,@body))
             (go ,g-start))))
       ,result)))

(defmacro case (keyform &body cases)
  (let ((var (gensym)))
    `(let ((,var ,keyform))
       (cond ,@(mapcar (lambda (c)
                         (cond ((eq 'otherwise (car c))
                                `(t ,@(cdr c)))
                               ((listp (car c))
                                `((member ,var ',(car c))
                                  ,@(cdr c)))
                               (t
                                `((eql ,var ',(car c))
                                  ,@(cdr c)))))
                       cases)))))

(defmacro ecase (keyform &body cases)
  (let ((var (gensym)))
    `(let ((,var ,keyform))
       (cond ,@(mapcar (lambda (c)
                         (cond ((listp (car c))
                                `((member ,var ',(car c))
                                  ,@(cdr c)))
                               (t
                                `((eql ,var ',(car c))
                                  ,@(cdr c)))))
                       cases)
             (t (error "ecase error"))))))

(defmacro multiple-value-bind (vars value-form &body body)
  (let ((rest (gensym)))
    `(multiple-value-call (lambda (&optional ,@vars &rest ,rest)
                            (declare (ignore ,rest))
                            ,@body)
       ,value-form)))

(defun %db-length (list)
  (do ((l list (cdr l))
       (count 0 (+ count 1)))
      ((atom l) count)))

(eval-when (:compile-toplevel)
  (defvar *db-bindings*)
  (defvar *tmp-db-vars*)

  (defun db-gensym (&optional arg)
    (car (push (if arg (gensym arg) (gensym)) *tmp-db-vars*)))

  (defun make-keyword (x)
    (intern (string x) :keyword))

  (defun parse-db-lambda-list (lambda-list arg)
    (flet ((invalid-lambda-list ()
             (error "Invalid lambda list: ~S" lambda-list)))
      (let ((path arg)
            (min 0)
            (max 0)
            (state nil)
            (optionalp nil)
            (restp nil)
            (keyp nil)
            (keys nil)
            (allow-other-keys-p nil)
            (check-arg-placeholder)
            (check-key-placeholder))
        (push (setf check-arg-placeholder (list (db-gensym) nil)) *db-bindings*)
        (when (eq '&whole (first lambda-list))
          (pop lambda-list)
          (unless lambda-list
            (invalid-lambda-list))
          (push (list (pop lambda-list) arg) *db-bindings*))
        (do ((ll lambda-list (rest ll)))
            ((atom ll)
             (when ll
               (setq restp t)
               (push (list ll path) *db-bindings*)))
          (let ((x (first ll)))
            (cond ((eq state :aux)
                   (cond ((symbolp x)
                          (push (list x nil) *db-bindings*))
                         ((consp x)
                          (case (length x)
                            ((1 2)
                             (push (list (first x)
                                         (second x))
                                   *db-bindings*))
                            (otherwise
                             (invalid-lambda-list))))
                         (t
                          (invalid-lambda-list))))
                  ((eq x '&aux)
                   (setq state :aux))
                  ((eq x '&allow-other-keys)
                   (unless (eq state :key) (invalid-lambda-list))
                   (setq allow-other-keys-p t))
                  ((eq x '&key)
                   (when keyp
                     (invalid-lambda-list))
                   (push (setf check-key-placeholder (list (db-gensym) path)) *db-bindings*)
                   (setq state :key)
                   (setq keyp t))
                  ((eq state :key)
                   (incf max 2)
                   (cond ((symbolp x)
                          (let ((key (make-keyword x)))
                            (push key keys)
                            (push (list x `(getf ,path ,key))
                                  *db-bindings*)))
                         ((consp x)
                          (let ((len (length x)))
                            (cond ((<= 1 len 3)
                                   (let ((key (make-keyword (first x))))
                                     (push key keys)
                                     (let ((supplied-value (db-gensym))
                                           (default ''#:default))
                                       (push (list supplied-value `(getf ,path ,key ,default))
                                             *db-bindings*)
                                       (when (= len 3)
                                         (push (list (third x) `(eq ,supplied-value ,default))
                                               *db-bindings*))
                                       (push (list (first x) `(if (eq ,supplied-value ,default)
                                                                  ,(second x)
                                                                  ,supplied-value))
                                             *db-bindings*))))
                                  (t
                                   (invalid-lambda-list)))))
                         (t
                          (invalid-lambda-list))))
                  ((member x '(&rest &body))
                   (setq restp t)
                   (cond ((and (rest ll) (symbolp (second ll)))
                          (push (list (second ll) path) *db-bindings*)
                          (pop ll))
                         ((and (rest ll) (consp (second ll)))
                          (let ((tmp (db-gensym "TMP")))
                            (push (list tmp path) *db-bindings*)
                            (parse-db-lambda-list (second ll) tmp)))
                         (t
                          (invalid-lambda-list))))
                  ((eq x '&optional)
                   (when optionalp
                     (invalid-lambda-list))
                   (setq state :optional)
                   (setq optionalp t))
                  ((eq state :optional)
                   (incf max)
                   (cond ((symbolp x)
                          (push (list x `(first ,path)) *db-bindings*)
                          (let ((cdr-var (db-gensym "TMP")))
                            (push (list cdr-var `(rest ,path)) *db-bindings*)
                            (setq path cdr-var)))
                         ((consp x)
                          (let ((len (length x)))
                            (cond ((<= 1 len 3)
                                   (when (= len 3)
                                     (push (list (third x) `(if ,path t nil))
                                           *db-bindings*))
                                   (push (list (first x) `(if ,path (first ,path) ,(second x)))
                                         *db-bindings*)
                                   (let ((cdr-var (db-gensym "TMP")))
                                     (push (list cdr-var `(rest ,path)) *db-bindings*)
                                     (setq path cdr-var)))
                                  (t
                                   (invalid-lambda-list)))))
                         (t
                          (invalid-lambda-list))))
                  ((listp x)
                   (incf min)
                   (incf max)
                   (let ((car-var (db-gensym "TMP")))
                     (push (list car-var `(first ,path)) *db-bindings*)
                     (parse-db-lambda-list x car-var))
                   (let ((cdr-var (db-gensym "TMP")))
                     (push (list cdr-var `(rest ,path)) *db-bindings*)
                     (setq path cdr-var)))
                  (t
                   (unless (symbolp x) (invalid-lambda-list))
                   (incf min)
                   (incf max)
                   (push (list x `(first ,path)) *db-bindings*)
                   (let ((cdr-var (db-gensym "TMP")))
                     (push (list cdr-var `(rest ,path)) *db-bindings*)
                     (setq path cdr-var))))))
        (setf (second check-arg-placeholder)
              `(unless ,(if (or restp keyp)
                            `(<= ,min (%db-length ,arg))
                            `(<= ,min (%db-length ,arg) ,max))
                 (error "Invalid number of arguments: ~S ~S" ',lambda-list ,arg)))
        (when (and check-key-placeholder
                   (not allow-other-keys-p))
          (setf (second check-key-placeholder)
                (let ((plist (gensym)))
                  `(do ((,plist ,(second check-key-placeholder) (cddr ,plist)))
                       ((null ,plist))
                     (unless (or ,@(mapcar (lambda (key) `(eq ,key (first ,plist))) keys))
                       (error "Unknown &key argument: ~S" (first ,plist))))))))))

  (defun expand-destructuring-bind (lambda-list expression body)
    (let ((*db-bindings* '())
          (*tmp-db-vars* '())
          (g-expression (gensym)))
      (parse-db-lambda-list lambda-list g-expression)
      `(let ((,g-expression ,expression))
         (let* ,(nreverse *db-bindings*)
           (declare (ignorable . ,*tmp-db-vars*))
           ,@body)))))

(defmacro destructuring-bind (lambda-list expression &body body)
  (expand-destructuring-bind lambda-list expression body))

(defmacro multiple-value-call (function arg &rest args)
  (if (null args)
      `(system::multiple-value-call (ensure-function ,function)
         ,(if (atom arg)
              `(values ,arg)
              arg))
      `(system::multiple-value-call (ensure-function ,function)
         ,arg
         ,@(if (atom (car (last args)))
               `(,@(butlast args) (values ,@(last args)))
               args))))

(defun eql (x y)
  (eq x y))

(defun equal (x y)
  (cond ((and (consp x)
              (consp y))
         (and (equal (car x) (car y))
              (equal (cdr x) (cdr y))))
        (t
         (eql x y))))
