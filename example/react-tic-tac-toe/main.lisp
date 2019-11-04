(ffi:require js:react "react")
(ffi:require js:react-dom "react-dom")

(define-react-component js:-square (on-click value)
  (tag :button (:class-name #j"square" :on-click on-click)
       value))

(define-react-component js:-board (squares on-click)
  (flet ((render-square (i)
           (tag js:-square (:value (or (aref squares i) #j:null)
                            :on-click (lambda (args)
                                        (declare (ignore args))
                                        (funcall on-click i))))))
    (tag :div ()
         (tag :div (:class-name #j"board-row")
              (render-square 0)
              (render-square 1)
              (render-square 2))
         (tag :div (:class-name #j"board-row")
              (render-square 3)
              (render-square 4)
              (render-square 5))
         (tag :div (:class-name #j"board-row")
              (render-square 6)
              (render-square 7)
              (render-square 8)))))

(defstruct moment
  turn
  squares)

(defun calculate-winner (squares)
  (macrolet ((line-test (x y z)
               `(let ((tmp (aref squares ,x)))
                  (if (and tmp
                           (equal tmp (aref squares ,y))
                           (equal tmp (aref squares ,z)))
                      tmp))))
    (or (line-test 0 1 2)
        (line-test 3 4 5)
        (line-test 6 7 8)
        (line-test 0 3 6)
        (line-test 1 4 7)
        (line-test 2 5 8)
        (line-test 0 4 8)
        (line-test 2 4 6))))

(defun map-index (type fn sequence)
  (let ((i 0))
    (map type
         (lambda (x)
           (declare (ignore x))
           (prog1 (funcall fn i)
             (incf i)))
         sequence)))

(define-react-component js:-game ()
  (with-state ((history set-history (list (make-moment :turn 0 :squares (make-array 9 :initial-element nil))))
               (step-number set-step-number 0)
               (x-turn-p set-x-turn-p t))
    (flet ((handle-click (i)
             (let* ((history (subseq history 0 (1+ step-number)))
                    (current (car (last history)))
                    (squares (copy-seq (moment-squares current))))
               (setf (aref squares i) (if x-turn-p "X" "O"))
               (let ((history-length (length history)))
                 (set-history (append history
                                      (list (make-moment :turn history-length
                                                         :squares squares))))
                 (set-step-number history-length)
                 (set-x-turn-p (not x-turn-p)))))
           (jump-to (step)
             (set-step-number step)
             (set-x-turn-p (evenp step))))
      (let* ((current (elt history step-number))
             (winner (calculate-winner (moment-squares current)))
             (moves (map-index 'vector
                               (lambda (move)
                                 (let ((desc (if (zerop move)
                                                 "Go to game start"
                                                 (format nil "Go to move #~D" move))))
                                   (tag :li (:key move)
                                        (tag :button (:on-click (lambda (&rest args)
                                                                  (declare (ignore args))
                                                                  (jump-to move)))
                                             desc))))
                               history))
             (status (if winner
                         (format nil "Winner: ~A" winner)
                         (format nil "Next player: ~A" (if x-turn-p "X" "O")))))
        (tag :div (:class-name #j"game")
             (tag :div (:class-name #j"game-board")
                  (tag js:-board
                       (:squares (moment-squares current)
                        :on-click (lambda (i)
                                    (unless winner
                                      (handle-click i)))))
                  (tag :div (:class-name #j"game-info")
                       (tag :div () status)
                       (tag :div () moves))))))))

(js:react-dom.render
 (tag js:-game ())
 (js:document.get-element-by-id #j"root"))
