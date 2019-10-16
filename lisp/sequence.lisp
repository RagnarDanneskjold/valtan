(in-package :common-lisp)

(defun check-both-bounds (start end length)
  (when (or (< length start) (and end (< length end)))
    (error "out of bounds")))

(defun map-sequence (function sequence from-end start end key)
  (when (or start end)
    (setq sequence (subseq sequence (or start 0) end)))
  (when from-end
    (setq sequence (reverse sequence)))
  (cond ((listp sequence)
         (if key
             (dolist (x sequence)
               (funcall function (funcall key x)))
             (dolist (x sequence)
               (funcall function x))))
        ((vectorp sequence)
         (if key
             (dotimes (i (length sequence))
               (funcall function (funcall key (aref sequence i))))
             (dotimes (i (length sequence))
               (funcall function (aref sequence i)))))
        (t
         (type-error sequence 'sequence))))

(defun map-sequences (function sequences)
  (let ((sequences (copy-list sequences)))
    (do ((i 0 (1+ i))
         (length (apply #'min (mapcar #'length sequences))))
        ((>= i length) nil)
      (funcall function (mapcar (lambda (s) (elt s i)) sequences)))))

(defun copy-seq (sequence)
  (cond ((listp sequence)
         (copy-list sequence))
        ((vectorp sequence)
         (make-array (length sequence)
                     :element-type (array-element-type sequence)
                     :initial-contents sequence))
        (t
         (type-error sequence 'sequence))))

(defun elt (sequence index)
  (cond ((consp sequence)
         (let ((result (nthcdr index sequence)))
           (if result
               (car result)
               (error "The index ~A is too large." index))))
        ((vectorp sequence)
         (aref sequence index))
        (t
         (type-error sequence 'sequence))))

(defun (setf elt) (value sequence index)
  (cond ((consp sequence)
         (let ((result (nthcdr index sequence)))
           (rplaca result value)))
        ((vectorp sequence)
         (setf (aref sequence index) value))
        (t
         (type-error sequence 'sequence))))

(defun fill (sequence item &key (start 0) end)
  (cond ((listp sequence)
         (let ((list (nthcdr start sequence)))
           (do ((list list (cdr list))
                (start start (1+ start)))
               ((if end (>= start end) (null list))
                sequence)
             (rplaca list item))))
        ((vectorp sequence)
         (unless end (setq end (length sequence)))
         (do ((i start (1+ i)))
             ((>= i end) sequence)
           (setf (aref sequence i) item)))
        (t
         (type-error sequence 'sequence))))

(defun make-sequence (result-type size &key (initial-element nil initial-element-p))
  (setq result-type (canonicalize-type result-type))
  (let ((name (if (consp result-type) (car result-type) result-type))
        (args (if (consp result-type) (cdr result-type) nil)))
    (case (car result-type)
      (null
       (unless (zerop size)
         (error "The length requested (1) does not match the type restriction in NULL."))
       nil)
      ((list cons)
       (when (and (eq name 'cons) (zerop size))
         (error "The length requested (0) does not match the type restriction in CONS."))
       (if initial-element-p
           (make-list size :initial-element initial-element)
           (make-list size)))
      (array
       (make-array size
                   :initial-element initial-element
                   :element-type (or (car args) t)))
      (otherwise
       (type-error result-type 'sequence)))))

(defun subseq-list (list start end)
  (when (and start
             (< 0 start))
    (setq list (nthcdr (1- start) list))
    (when (null list)
      (error "index error"))
    (setq list (cdr list)))
  (cond ((null end)
         (copy-list list))
        ((eql start end)
         nil)
        (t
         (setq end (- end start))
         (let ((new-list (copy-list list)))
           (setf (cdr (nthcdr (1- end) new-list)) nil)
           new-list))))

(defun subseq-vector (vector start end)
  (let ((length (length vector)))
    (when (and end (< length end))
      (error "index error"))
    (unless end
      (setq end length))
    ;; XXX: javascriptのArrayのメソッドを使わず新しいベクタに一つずつ代入していて効率が悪い
    (let ((new-vector
            (make-array (- end start) :element-type (array-element-type vector))))
      (do ((i start (1+ i))
           (j 0 (1+ j)))
          ((= i end))
        (setf (aref new-vector j)
              (aref vector i)))
      new-vector)))

(defun subseq (sequence start &optional end)
  (when (and (not (null end)) (> start end))
    (error "start > end"))
  (cond ((listp sequence)
         (subseq-list sequence start end))
        ((vectorp sequence)
         (subseq-vector sequence start end))
        (t
         (type-error sequence 'sequence))))

(defun (setf subseq) (new-subsequence sequence start &optional end)
  (replace sequence new-subsequence :start1 start :end1 end)
  new-subsequence)

(defun map (result-type function sequence &rest more-sequences)
  (setq result-type (canonicalize-type result-type))
  (cond ((and (null result-type) (null more-sequences))
         (map-sequence function sequence nil nil nil nil)
         nil)
        ((null result-type)
         (map-sequences (lambda (args)
                          (apply function args))
                        (cons sequence more-sequences))
         nil)
        (t
         (let ((acc '())
               (length 0))
           (map-sequences (lambda (args)
                            (incf length)
                            (push (apply function args) acc))
                          (cons sequence more-sequences))
           (setq acc (nreverse acc))
           (let ((type-name (if (consp result-type)
                                (car result-type)
                                result-type))
                 (type-args (if (consp result-type)
                                (cdr result-type)
                                nil)))
             (case type-name
               (null
                (when acc
                  (type-error acc 'null))
                nil)
               ((list cons)
                acc)
               (array
                (make-array length
                            :initial-contents acc
                            :element-type (if type-args
                                              (car type-args)
                                              t)))
               (otherwise
                (type-error result-type 'sequence))))))))

#+(or)
(defun map-into (result-sequence function &rest sequences)
  )

#+(or)
(defun reduce (function sequence &key key from-end start end initial-value)
  )

(defun length (sequence)
  (cond ((listp sequence)
         (list-length sequence))
        ((vectorp sequence)
         (array-length-with-fill-pointer sequence))
        (t
         (type-error sequence 'sequence))))

(defun reverse-list (list)
  (let ((reversed-list '()))
    (dolist (x list)
      (push x reversed-list))
    reversed-list))

(defun reverse-vector (vector)
  (let* ((length (length vector))
         (new-vector (make-array length :element-type (array-element-type vector))))
    (do ((i 0 (1+ i))
         (j (1- length) (1- j)))
        ((= i length))
      (setf (aref new-vector i)
            (aref vector j)))
    new-vector))

(defun reverse (sequence)
  (cond ((listp sequence)
         (reverse-list sequence))
        ((vectorp sequence)
         (reverse-vector sequence))
        (t
         (type-error sequence 'sequence))))

(defun nreverse-list (list)
  (do ((1st (cdr list) (if (endp 1st) 1st (cdr 1st)))
       (2nd list 1st)
       (3rd '() 2nd))
      ((atom 2nd) 3rd)
    (rplacd 2nd 3rd)))

(defun nreverse-vector (vector)
  (let ((length (length vector)))
    (dotimes (i (floor length 2))
      (let ((j (- length i 1)))
        (let ((x (aref vector i))
              (y (aref vector (- length i 1))))
          (setf (aref vector i) y
                (aref vector j) x)))))
  vector)

(defun nreverse (sequence)
  (cond ((listp sequence)
         (nreverse-list sequence))
        ((vectorp sequence)
         (nreverse-vector sequence))
        (t
         (type-error sequence 'sequence))))

#+(or)
(defun sort (sequence predicate &key key)
  )

(defun stable-sort-list (list predicate key)
  (labels ((merge* (list1 list2)
             (let ((list3 '()))
               (do ()
                   ((or (null list1) (null list2))
                    (if (null list1)
                        (nconc (nreverse list3) list2)
                        (nconc (nreverse list3) list1)))
                 (if (apply-key key (funcall predicate (car list1) (car list2)))
                     (push (pop list1) list3)
                     (push (pop list2) list3)))))
           (rec (list)
             (let ((size (length list)))
               (cond ((<= size 1)
                      list)
                     (t
                      (let* ((middle (floor size 2))
                             (left (stable-sort-list (subseq list 0 middle) predicate key))
                             (right (stable-sort-list (subseq list middle) predicate key)))
                        (merge* right left)))))))
    (rec list)))

(defun stable-sort-vector (vector predicate key)
  (let* ((size (length vector))
         (temp (make-array size)))
    (labels ((merge* (left middle right)
               (do ((i left)
                    (j middle)
                    (k 0 (1+ k)))
                   ((or (>= i middle)
                        (>= j right))
                    (if (< i middle)
                        (do ((i i (1+ i)))
                            ((>= i middle))
                          (setf (aref temp k) (aref vector i))
                          (incf k))
                        (do ((j j (1+ j)))
                            ((>= j right))
                          (setf (aref temp k) (aref vector j))
                          (incf k)))
                    (dotimes (i k)
                      (setf (aref vector (+ left i)) (aref temp i))))
                 (cond ((not (funcall predicate
                                      (apply-key key (aref vector j))
                                      (apply-key key (aref vector i))))
                        (setf (aref temp k) (aref vector i))
                        (incf i))
                       (t
                        (setf (aref temp k) (aref vector j))
                        (incf j)))))
             (rec (left right)
               (if (>= 1 (- right left))
                   nil
                   (let ((middle (floor (+ left right) 2)))
                     (rec left middle)
                     (rec middle right)
                     (merge* left middle right)))))
      (rec 0 size)
      (dotimes (i size)
        (setf (aref vector i)
              (aref temp i)))
      vector)))

(defun stable-sort (sequence predicate &key key)
  (cond ((listp sequence)
         (stable-sort-list sequence predicate key))
        ((vectorp sequence)
         (stable-sort-vector sequence predicate key))
        (t
         (type-error sequence 'sequence))))

(defun find (item sequence &key from-end start end key test test-not)
  (map-sequence (cond (test
                       (lambda (x)
                         (when (funcall test item (apply-key key x))
                           (return-from find x))))
                      (test-not
                       (lambda (x)
                         (when (not (funcall test-not item (apply-key key x)))
                           (return-from find x))))
                      (t
                       (lambda (x)
                         (when (eql item (apply-key key x))
                           (return-from find x)))))
                sequence
                from-end
                start
                end
                nil))

(defun find-if (predicate sequence &key from-end start end key)
  (map-sequence (lambda (x)
                  (when (funcall predicate (apply-key key x))
                    (return-from find-if x)))
                sequence
                from-end
                start
                end
                nil)
  nil)

(defun find-if-not (predicate sequence &rest args &key from-end start end key)
  (declare (ignore from-end start end key))
  (apply #'find-if (complement predicate) sequence args))

(defun position (item sequence &key from-end test test-not (start 0) (end (length sequence)) key)
  (let ((pos (if from-end (1- end) start)))
    (map-sequence (cond (test
                         (lambda (x)
                           (when (funcall test item x)
                             (return-from position pos))
                           (if from-end
                               (decf pos)
                               (incf pos))))
                        (test-not
                         (lambda (x)
                           (when (not (funcall test-not item x))
                             (return-from position pos))
                           (if from-end
                               (decf pos)
                               (incf pos))))
                        (t
                         (lambda (x)
                           (when (eql item x)
                             (return-from position pos))
                           (if from-end
                               (decf pos)
                               (incf pos)))))
                  sequence
                  from-end
                  start
                  end
                  key)
    nil))

(defun position-if (predicate sequence &key from-end (start 0) (end (length sequence)) key)
  (let ((pos (if from-end (1- end) start)))
    (map-sequence (lambda (x)
                    (when (funcall predicate (apply-key key x))
                      (return-from position-if pos))
                    (if from-end
                        (decf pos)
                        (incf pos)))
                  sequence
                  from-end
                  start
                  end
                  key)))

(defun position-if-not (predicate sequence &rest args &key from-end start end key)
  (declare (ignore from-end start end key))
  (apply #'position-if (complement predicate) sequence args))

#+(or)
(defun search (sequence-1 sequence-2 &key from-end test test-not key start1 start2 end1 end2)
  )

#+(or)
(defun mismatch (sequence-1 sequence-2 &key from-end test test-not key start1 start2 end1 end2)
  )

(defun replace (target-sequence source-sequence &key (start1 0) end1 (start2 0) end2)
  (let ((length1 (length target-sequence))
        (length2 (length source-sequence)))
    (check-both-bounds start1 end1 length1)
    (check-both-bounds start2 end2 length2)
    (unless end1 (setq end1 length1))
    (unless end2 (setq end2 length2))
    (let ((width1 (- end1 start1))
          (width2 (- end2 start2)))
      (dotimes (i (min width1 width2))
        (setf (elt target-sequence (+ start1 i))
              (elt source-sequence (+ start2 i))))))
  target-sequence)

#+(or)
(defun substitute (new old sequence &key from-end test test-not start end count key)
  )

#+(or)
(defun substitute-if (new predicate sequence &key from-end start end count key)
  )

#+(or)
(defun substitute-if-not (new predicate sequence &key from-end start end count key)
  )

#+(or)
(defun nsubstitute (new old sequence &key from-end test test-not start end count key)
  )

#+(or)
(defun nsubstitute-if (new predicate sequence &key from-end start end count key)
  )

#+(or)
(defun nsubstitute-if-not (new predicate sequence &key from-end start end count key)
  )

#+(or)
(defun concatenate (result-type &rest sequences)
  )

#+(or)
(defun merge (result-type sequence-1 sequence-2 predicate &key key)
  )

(defun remove (item sequence &key (test nil test-p))
  (with-accumulate ()
    (map-sequence (if test-p
                      (lambda (x)
                        (unless (funcall test item x)
                          (collect x)))
                      (lambda (x)
                        (unless (eql item x)
                          (collect x))))
                  sequence
                  nil
                  0
                  nil
                  nil)))

(defun remove-if (test sequence &rest args &key from-end start end count key)
  (declare (ignore from-end start end count key))
  (apply #'remove-if-not (complement test) sequence args))

(defun remove-if-not (test sequence &key from-end start end count key)
  (with-accumulate ()
    (map-sequence (lambda (x)
                    (when (funcall test x)
                      (collect x)))
                  sequence
                  from-end
                  start
                  end
                  key)))

#+(or)
(defun delete (item sequence &key from-end test test-not start end count key)
  )

#+(or)
(defun delete-if (test sequence &key from-end start end count key)
  )

#+(or)
(defun delete-if-not (test sequence &key from-end start end count key)
  )

#+(or)
(defun remove-duplicates (sequence &key from-end test test-not start end key)
  )

#+(or)
(defun delete-duplicates (sequence &key from-end test test-not start end key)
  )

(defun every (function sequence &rest more-sequences)
  (cond ((null more-sequences)
         (map-sequence (lambda (x)
                         (unless (funcall function x)
                           (return-from every nil)))
                       sequence
                       nil
                       nil
                       nil
                       nil)
         t)
        (t
         (map-sequences (lambda (args)
                          (unless (apply function args)
                            (return-from every nil)))
                        (cons sequence more-sequences))
         t)))

(defun some (function sequence &rest more-sequences)
  (cond ((null more-sequences)
         (map-sequence (lambda (x)
                         (when (funcall function x)
                           (return-from some t)))
                       sequence
                       nil
                       nil
                       nil
                       nil)
         nil)
        (t
         (map-sequences (lambda (args)
                          (when (apply function args)
                            (return-from some t)))
                        (cons sequence more-sequences))
         nil)))

(defun notany (function sequence &rest more-sequences)
  (not (apply #'some function sequence more-sequences)))
