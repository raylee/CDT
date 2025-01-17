(load "../utilities.lisp")
(load "globals.lisp")
(load "simplex.lisp")
(load "moves.lisp")
(load "initialization.lisp")
(load "montecarlo.lisp")
; JM: spacetime-spectral-dimension.lisp does not exist. Probably
; deprecated.
;(load "spacetime-spectral-dimension.lisp")

;+---------------------------------------------------------------------------------------------------------+
;| cdt-2+1-globals.lisp --- all the parameters that might need to be accessed from multiple files          |
;+---------------------------------------------------------------------------------------------------------+

; we use the same random state during testing to verify that the bugs
; are being fixed.  

;; JM: Currently these files are missing. I don't know where David put
;; them, but they could be lost to time. It is probably possible
;; regenerate them. However, since they're for degugging purposes
;; only, I think the code will continue to work without them. I'm
;; commenting them. To debug with random state files, uncomment these
;; lines and comment the line with the comment "RANDOM STATE MAKER."
;#+ :sbcl (with-open-file (rndstt "../cdt-random-state-004.rndsbcl" :direction :input)
;	   (setf *random-state* (read rndstt)))
;#+ :ccl (with-open-file (rndstt "../cdt-random-state-001.rndccl" :direction :input)
;	  (setf *random-state* (read rndstt)))

;; comment the following line to use a fixed seed from above
(setf *random-state* (make-random-state t)) ; RANDOM STATE MAKER

(defun reload-random-state ()
  #+ :sbcl (with-open-file (rndstt "../cdt-random-state-004.rndsbcl" :direction :input)
	     (setf *random-state* (read rndstt)))
  #+ :ccl (with-open-file (rndstt "../cdt-random-state-001.rndccl" :direction :input)
	    (setf *random-state* (read rndstt)))
  )

(defparameter *LAST-USED-2SXID* 0)
(defparameter *LAST-USED-3SXID* 0)
(defparameter *RECYCLED-3SX-IDS* '())
(defparameter *LAST-USED-POINT* 0)
(defparameter *LAST-USED-S2SXID* 0)

(defmacro next-pt ()
  `(incf *LAST-USED-POINT*))
(defmacro set-last-used-pt (pt)
  `(setf *LAST-USED-POINT* ,pt))
(defmacro next-spatial-2simplex-id ()
  `(incf *LAST-USED-S2SXID*))
(defmacro next-2simplex-id ()
  `(incf *LAST-USED-2SXID*))
(defmacro next-3simplex-id ()
  `(if (null *RECYCLED-3SX-IDS*)
       (incf *LAST-USED-3SXID*)
       (pop *RECYCLED-3SX-IDS*)))
(defmacro recycle-3simplex-id (sxid)
  `(push ,sxid *RECYCLED-3SX-IDS*))

(defun 2simplex->id-equality (2sx1 2sx2)
  (set-equal? (fourth 2sx1) (fourth 2sx2)))
(defun 2simplex->id-hashfn (2sx)
  (sxhash (sort (copy-list (fourth 2sx)) #'<)))

;;macro to determine the euler characteristic of the spatial slices
;;assumes that the only two available are s2 and t2
(defmacro euler-char ()
  `(if (string= STOPOLOGY "S2") 2 1)) 
;; rkommu 2011-05-03 the second number above (chi for torus) should be 0

#+sbcl
(sb-ext:define-hash-table-test 2simplex->id-equality 2simplex->id-hashfn)

(defparameter *ID->SPATIAL-2SIMPLEX* (make-hash-table))

#+sbcl
(defparameter *2SIMPLEX->ID* (make-hash-table :test '2simplex->id-equality)) 

#+ccl
(defparameter *2SIMPLEX->ID* (make-hash-table :test '2simplex->id-equality 
					      :hash-function '2simplex->id-hashfn))

(defparameter *ID->2SIMPLEX* (make-hash-table))

(defparameter *ID->3SIMPLEX* (make-hash-table :test 'equal))

(defconstant 26MTYPE 0 "move type (2,6)")
(defconstant 23MTYPE 1 "move type (2,3)")
(defconstant 44MTYPE 2 "move type (4,4)")
(defconstant 32MTYPE 3 "move type (3,2)")
(defconstant 62MTYPE 4 "move type (6,2)")

(defconstant ROOT2 (sqrt 2.0))
(defconstant KAPPA (/ (acos (/ 1 3)) pi))
(defconstant 6ROOT2 (* 6.0 ROOT2))
(defconstant 3KAPPAMINUS1 (- (* 3 KAPPA) 1))

(defparameter ATTEMPTED-MOVES (list 1 1 1 1 1) "number of attempted moves for each move type")
(defparameter SUCCESSFUL-MOVES (list 1 1 1 1 1) "number of successful moves for each move type")

(defun reset-move-counts ()
  (for (n 0 4)
       (setf (nth n ATTEMPTED-MOVES) 1 (nth n SUCCESSFUL-MOVES) 1)))

(defun accept-ratios ()
  (format nil "[~A ~A ~A ~A ~A]"
	  (* 100.0 (/ (nth 0 SUCCESSFUL-MOVES) (nth 0 ATTEMPTED-MOVES)))
	  (* 100.0 (/ (nth 1 SUCCESSFUL-MOVES) (nth 1 ATTEMPTED-MOVES)))
	  (* 100.0 (/ (nth 2 SUCCESSFUL-MOVES) (nth 2 ATTEMPTED-MOVES)))
	  (* 100.0 (/ (nth 3 SUCCESSFUL-MOVES) (nth 3 ATTEMPTED-MOVES)))
	  (* 100.0 (/ (nth 4 SUCCESSFUL-MOVES) (nth 4 ATTEMPTED-MOVES)))))

(defmacro percent-tv ()
  `(* 100.0 (/ (abs (- (N3) N-INIT)) N-INIT)))

(defparameter N0 0 "number of points")
(defparameter N1-SL 0 "number of spacelike links")
(defparameter N1-TL 0 "number of timelike links")
(defparameter N2-SL 0 "number of spacelike triangles")
(defparameter N2-TL 0 "number of timelike triangles")
(defparameter N3-TL-31 0 "number of (1,3) + (3,1) timelike tetrahedra")
(defparameter N3-TL-22 0 "number of (2,2) timelike tetrahedra")
(defmacro N3 ()
  "total number of timelike 3simplices (tetrahedra)"
  `(+ N3-TL-31 N3-TL-22))

(defun set-f-vector (v1 v2 v3 v4 v5 v6 v7)
  (setf N0 v1 N1-SL v2 N1-TL v3 N2-SL v4 N2-TL v5 N3-TL-31 v6 N3-TL-22 v7))
(defun update-f-vector (dv)
  (incf N0 (nth 0 dv))
  (incf N1-SL (nth 1 dv))
  (incf N1-TL (nth 2 dv))
  (incf N2-SL (nth 3 dv))
  (incf N2-TL (nth 4 dv))
  (incf N3-TL-31 (nth 5 dv))
  (incf N3-TL-22 (nth 6 dv)))

;;make the deltas of the f-vector macros, so that
;;they can vary depending on whether the simplex on which
;;the move is performed is at a boundary

;;first, define macros to determine helpful things about
;;the position of a particular simplex
(defmacro in-upper-sandwich (sxid) 
  `(and (string= BCTYPE "OPEN") (= (3sx-tmhi (get-3simplex ,sxid))) NUM-T))
(defmacro in-lower-sandwich (sxid)
  `(and (string= BCTYPE "OPEN") (= (3sx-tmlo (get-3simplex ,sxid))) 0))
(defmacro in-either-boundary-sandwich (sxid)
  `(or (in-upper-sandwich ,sxid) (in-lower-sandwich ,sxid)))
(defmacro has-face-on-boundary (sxid)
  `(let* ((sx (get-3simplex ,sxid))  ;for fixed boundaries, this is unnecessary
	  (ty (3sx-type sx))
	  (th (3sx-tmhi sx))
	  (tl (3sx-tmlo sx)))
     (and (string= BCTYPE "OPEN")
	  (or (and (= ty 1)
		   (or (= th 0) (= th NUM-T)))
	      (and (= ty 3)
		   (or (= tl 0) (= tl NUM-T)))))))

;;use the above macros to help determine when special
;;DF's need to be applied
(defmacro DF26 (sxid)
  `(if (has-face-on-boundary ,sxid) ;for fixed boundaries, this is unnecessary
       (list 1 3 1 2 3 2 0)
       (list 1 3 2 2 6 4 0)))
(defmacro DF62 (sxid)
  `(if (has-face-on-boundary ,sxid) ;for fixed boundaries, this is unnecessary
       (list -1 -3 -1 -2 -3 -2 0)
       (list -1 -3 -2 -2 -6 -4 0)))
(defparameter DF44 (list 0 0 0 0 0 0 0))
(defparameter DF23 (list 0 0  1 0  2 0  1))
(defparameter DF32 (list 0 0 -1 0 -2 0 -1))


;;define some quantities of geometrical objects on the boundaries
(defparameter N1-SL-boundary 0)
(defparameter N3-22-boundary 0)
(defparameter N3-31-boundary 0)

;;the above three quantities compose the "b-vector"
(defun set-b-vector (n1 n2 n3)
  (setf N1-SL-boundary n1
	N3-22-boundary n2
	N3-31-boundary n3))
(defun update-b-vector (dv)
  (incf N1-SL-boundary (first  dv))
  (incf N3-22-boundary (second dv))
  (incf N3-31-boundary (third  dv)))

;;the deltas of the b-vector are dependent on where a move occurs
(defmacro DB26 (sxid)
  `(if (has-face-on-boundary ,sxid) ;for fixed boundaries, this is unnecessary
       (list 3 0 2) 
       (list 0 0 0)))
(defmacro DB62 (sxid)
  `(if (has-face-on-boundary ,sxid) ;for fixed boundaries, this is unnecessary
       (list -3 0 -2) 
       (list  0 0  0)))
(defparameter DB44 (list 0 0 0))
(defmacro DB23 (sxid)
  `(if (in-either-boundary-sandwich ,sxid)
       (list 0 1 0)
       (list 0 0 0)))
(defmacro DB32 (sxid)
  `(if (in-either-boundary-sandwich ,sxid)
       (list 0 -1 0)
       (list 0  0 0)))


(defparameter CURRENT-MOVE-IDENTIFIER "UNKNOWN")
(defparameter CURRENT-MOVE-NUMBER 0)
(defparameter STOPOLOGY "unknown" "spatial slice topology --- S2 or T2")
(defparameter BCTYPE "unknown" "boundary conditions --- PERIODIC or OPEN")
(defparameter SAVE-EVERY-N-SWEEPS 10 "save every 10 sweeps by default")
(defparameter NUM-T 666666 "number of time slices --- set to a non-zero value so (mod ts NUM-T) works")
(defparameter N-INIT 0 "initial volume of spacetime; we try to keep the volume close to this number")
(defparameter NUM-SWEEPS 0 "number of sweeps for which the simulation is to run")
(defparameter k0 0.0)
(defparameter k3 0.0)
(defparameter eps 0.02)
(defparameter SIM-START-TIME (cdt-now-str) "set again inside the generate methods for more accurate value")


#+ :sbcl 
(defparameter RNDEXT ".rndsbcl" "used for storing the random state under SBCL compiler")
#+ :ccl 
(defparameter RNDEXT ".rndccl" "used for storing the random state under CCL compiler")

(defparameter 3SXEXT ".3sx2p1" "used for storing the parameters and 3simplex information")
(defparameter PRGEXT ".prg2p1" "used for keeping track of the progress of a simulation run")
(defparameter MOVEXT ".mov2p1" "used for storing the movie data information")

(defvar action nil)

;;(defun action-S1xS2 (num-0 num-3)
;;  (+ (- (* k3 num-3) (* k0 num-0)) (* eps (abs (- num-3 N-INIT)))))

;;; wrsqrt is the "wick rotated" sqrt function. Basically 
;;; wrsqrt(x) = -i*sqrt(-x) when x < 0 and not i*sqrt(-x). 
;;; So wrsqrt(-1) = -i
(defmacro wrsqrt (val)
  `(if (< ,val 0)
       (* -1 *i* (sqrt (* -1 ,val)))
       (sqrt ,val)))

(defparameter *a* 1.0)
(defparameter *alpha* -1.0)
(defparameter *i* #C(0.0 1.0)) ; complex number i
(defparameter *-i* #C(0.0 -1.0)) ; complex number -i
(defparameter *2pi/i* (/ (* 2 pi) *i*)) ; Self explanatory
(defparameter *3/i* (/ 3 *i*)) ; Self explanatory
(defparameter *2/i* (/ 3 *i*)) ; Self explanatory
(defparameter *k* 1.0)
(defparameter *litL* 1.0)

;; STOPOLOGY-BCTYPE-NUMT-NINIT-k0-k3-eps-alpha-startsweep-endsweep-hostname-currenttime
(defun generate-filename (&optional (start-sweep 1) (end-sweep (+ start-sweep NUM-SWEEPS -1)))
  (format nil "~A-~A-T~3,'0d-V~6,'0d-~A-~A-~A-~A-~9,'0d-~9,'0d-on-~A-started~A" 
	  STOPOLOGY BCTYPE NUM-T N-INIT k0 k3 eps *alpha* start-sweep end-sweep (hostname) (cdt-now-str)))

;; STOPOLOGY-BCTYPE-NUMT-NINIT-k0-k3-eps-alpha-startsweep-currsweep-endsweep-hostname-starttime-currenttime
(defun generate-filename-v2 (&optional (ssweep 1) (csweep 0) (esweep (+ ssweep NUM-SWEEPS -1)))
  (format nil "~A-~A-T~3,'0d-V~6,'0d-~A-~A-~A-~A-~9,'0d-~9,'0d-~9,'0d-on-~A-start~A-curr~A" 
	  STOPOLOGY BCTYPE NUM-T N-INIT k0 k3 eps *alpha* ssweep csweep esweep 
	  (hostname) SIM-START-TIME (cdt-now-str)))

(defvar 26MARKER 0.0)
(defvar 23MARKER 0.0)
(defvar 44MARKER 0.0)
(defvar 32MARKER 0.0)
(defvar 62MARKER 0.0)

;;the dihedral angle of an equilateral tetrahedron
(defparameter *theta* (acos 1/3))
(defparameter *sxvol* (/ 1 (* 6 (sqrt 2))))

;; Define action as the _euclidean_ action, to be used directly as the
;; weight in the partition function. Assumes alpha = -1, a = 1
;; JM: Deprecated DO NOT USE.
(defun action-deprecated (num1-sl num1-tl num3-22  num3-31
	       ;;some additional arguments to be passed for
	       ;;open boundary conditions
	       num1-sl-boundary
	       num3-22-boundary
	       num3-31-boundary)

  ;;define some variables to ease the expression-writing
  (let* ((num3  (+ num3-22 num3-31))
	 (num1  (+ num1-sl num1-tl)))

    ;;expression for the euclidean action
    (+ (* *litL* *sxvol* num3) 
       (* (- *k*) (- (* 2 pi (- num1 num1-sl-boundary)) 
		     (* (- (* 6 num3) (* 3 num3-31-boundary) num3-22-boundary) *theta*)))
       
       ;;boundary term:
       (* (- *k*) (- (* pi num1-sl-boundary) (* *theta* (+ (* 3 num3-31-boundary) num3-22-boundary)))))))


;; Corrected action that uses arbitrary alpha and arbitrary k and
;; lambda. Set ret-coup to true for debugging. Note that the action is
;; purely complex. This is expected after Wick rotation and the
;; correct partition function is e^{i action}.  

;; TODO: Check to make sure physics is perfect. I'm not sure I should
;; divide by i everywhere I do in the boundary. I do so to make
;; everything real. If I'm off by anything, its probably just a sign,
;; but a sign will make all the difference.
(defun action (num1-sl num1-tl num3-31 num3-22 
	       ; Some additional arguments that need to be passed for
	       ; open boundary conditions. In theory, the number of
	       ; (3,1)-simplices connected to the boundary should be
	       ; looked at too. At the fixed bounary, they don't
	       ; change and have no effect on the dynamics. However at
	       ; the other boundary, which we do not keep fixed, they
	       ; have a substantial effect.
	       num1-sl-boundary ; spacelike links on boundary
	       num3-22-boundary ; (2,2)-simplices connected at boundary
	       num3-31-boundary ; (3,1)- and (1,3)-simplices connected at boundary
	       alpha k litL ; Tuning parameters
	       &optional (ret-coup nil))
  (let* ((2alpha+1 (+ (* 2 alpha) 1))
	 (4alpha+1 (+ (* 4 alpha) 1))
	 (4alpha+2 (+ (* 4 alpha) 2))
	 (3alpha+1 (+ (* 3 alpha) 1))
	 ; (2,2)-simpleses in the bulk
	 (num3-22-bulk (- num3-22 num3-22-boundary))
	 ; (3,1)-simplexes in the bulk
	 (num3-31-bulk (- num3-31 num3-31-boundary))
	 ; Space-like edges/links in the bulk
	 (num1-sl-bulk (- num1-sl num1-sl-boundary))
	 ; dihedral angle around spacelike bone for (2,2) simplices
	 (arcsin-1 (asin (/ (* *-i* (wrsqrt (* 8 2alpha+1))) 4alpha+1))) 
	 ; dihedral angle around spacelike bones for (3,1) simplices
	 (arccos-1 (acos (/ *-i* (wrsqrt (* 3 4alpha+1)))))
	 ;dihedral angle around timelike bones for (2,2) simplices
	 (arccos-2 (acos (/ -1 4alpha+1)))
	 ; dihedral angle around time-like bones for (3,1) simplices
	 (arccos-3 (acos (/ 2alpha+1 4alpha+1)))
	 ;; Bulk action assuming closed manifold.
	 (A (* *2pi/i* k))
	 (B (* (wrsqrt alpha) 2 pi k))
	 (C (- (+ (* *3/i* arccos-1 k) (* (wrsqrt alpha) 3 arccos-3 k) (* (/ litL 12) (wrsqrt 3alpha+1)))))
	 (D (- (+ (* *2/i* arcsin-1 k) (* (wrsqrt alpha) 4 arccos-2 k) (* (/ litL 12) (wrsqrt 4alpha+2)))))
	 (E (- (* k (/ pi *i*))))
	 (F (* *2/i* k arccos-1))
	 (G (* (/ k *i*) arcsin-1)))
    (if ret-coup
	(list arcsin-1 arccos-1 arccos-2 arccos-3 A B C D E F G)
	; Bulk term
	(+ (* A num1-sl-bulk k) (* B num1-tl) (* C num3-31-bulk) (* D num3-22-bulk)
	   ; Boundary term
	   (* E num1-sl-boundary) (* F num1-sl-boundary) (* G num3-22-boundary)))))



(defun damping (num3)
  (* eps (abs (- num3 N-INIT))))

(defun initialize-move-markers ()
  (setf 26MARKER 5.0)
  (setf 23MARKER (+ 26MARKER 5.0))
  (setf 44MARKER (+ 23MARKER 5.0))
  (setf 32MARKER (+ 44MARKER 5.0))
  (setf 62MARKER (+ 32MARKER 5.0)))

(defun update-move-markers ()
  (let ((num-successful-moves (apply #'+ SUCCESSFUL-MOVES)))
    (setf 26MARKER (float (/ num-successful-moves (nth 26MTYPE SUCCESSFUL-MOVES))))
    (setf 23MARKER (+ 26MARKER(float (/ num-successful-moves (nth 23MTYPE SUCCESSFUL-MOVES)))))
    (setf 44MARKER (+ 23MARKER(float (/ num-successful-moves (nth 44MTYPE SUCCESSFUL-MOVES)))))
    (setf 32MARKER (+ 44MARKER(float (/ num-successful-moves (nth 32MTYPE SUCCESSFUL-MOVES)))))
    (setf 62MARKER (+ 32MARKER(float (/ num-successful-moves (nth 62MTYPE SUCCESSFUL-MOVES)))))))

(defun select-move ()
  (let ((rndval (random 62MARKER))
	(mtype -1))
    (if (< rndval 26MARKER)
	(setf mtype 0)
	(if (< rndval 23MARKER)
	    (setf mtype 1)
	    (if (< rndval 44MARKER)
		(setf mtype 2)
		(if (< rndval 32MARKER)
		    (setf mtype 3)
		    (setf mtype 4)))))
    mtype))

(defun set-k0-k3-alpha (kay0 kay3 alpha)
  (setf k0 kay0 k3 kay3 *alpha* alpha)
  (setf *k* (/ k0 (* 2 *a* pi)))
  (setf *litL* (* (- k3 (* 2 *a* pi *k* 3KAPPAMINUS1)) (/ 6ROOT2 (* *a* *a* *a*))))
  (initialize-move-markers))

;;function analogous to set-k0-k3-alpha, but for k, litL, and alpha
;;(does not bother to set k0 and k3)
(defun set-k-litL-alpha (new-k new-litL new-alpha)
  (setf *k*     new-k
        *litL*  new-litL
        *alpha* new-alpha)
	
  ;;also set k0, k3 for compatibility with rest of code (saving/loading, filename generation, etc)
  (setf k0 (* *k* (* 2 *a* pi))
	k3 (+ (/ (* *litL* *a* *a* *a*) 6ROOT2) (* 2 *a* pi *k* 3KAPPAMINUS1)))

  (initialize-move-markers))



;;----------------------------------------------------------------------------------------------------------
;; initialization data
;;----------------------------------------------------------------------------------------------------------

;; 5, 6, 7, 8
;;------------ t=1
;; 1, 2, 3, 4
;;------------ t=0
(defparameter N0-PER-SLICE 4)
(defparameter N1-SL-PER-SLICE 6)
(defparameter N1-TL-PER-SLICE 12)
(defparameter N2-SL-PER-SLICE 4)
(defparameter N2-TL-PER-SLICE 24)
(defparameter N3-TL-13-PER-SLICE 4)
(defparameter N3-TL-22-PER-SLICE 6)
(defparameter N3-TL-31-PER-SLICE 4) ; here (3,1) means just (3,1), not (3,1)+(1,3)
(defparameter S2-1/2-31 '((1 2 3 5) (2 3 4 6) (3 4 1 7) (4 1 2 8)))
(defparameter S2-1/2-22 '((1 2 5 8) (2 3 5 6) (3 1 5 7) (3 4 6 7) (4 2 6 8) (4 1 7 8)))
(defparameter S2-1/2-13 '((1 5 7 8) (2 5 6 8) (3 5 6 7) (4 6 7 8)))

;; 13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44
;;------------------------------------------------------------------------------------------------- t=1
;; 1,2,3,4,5,6,7,8,9,10,11,12
;;------------------------------------------------------------------------------------------------- t=0
;;(defparameter N0-PER-2-SLICES 44)

;;(defparameter S2-1/2-31 '((1 2 3 13) (1 3 4 17) (1 4 5 21) (1 5 6 25) 
;;			  (1 6 2 29) (2 3 10 14) (2 6 9 30) (2 9 10 31) 
;;			  (3 4 11 18) (3 10 11 15) (4 5 7 22) (4 7 11 19) 
;;			  (5 6 8 26) (5 7 8 23) (6 8 9 27) (12 7 8 24) 
;;			  (12 8 9 28) (12 9 10 32) (12 10 11 16) (12 11 7 20)))
;;
;;(defparameter S2-1/2-22 '((2 3 13 14) (1 3 13 17) (3 4 17 18) (3 11 15 18) 
;;			  (3 10 14 15) (1 4 17 21) (4 5 21 22) (4 7 19 22) 
;;			  (4 11 18 19) (1 5 21 25) (5 6 25 26) (5 8 23 26) 
;;			  (5 7 22 23) (1 6 25 29) (6 2 29 30) (6 9 27 30) 
;;			  (6 8 26 27) (10 11 15 16) (11 12 16 20) (11 7 19 20)
;;			  (7 12 20 24) (7 8 23 24) (8 12 24 28) (8 9 27 28) 
;;			  (9 12 28 32) (9 10 31 32) (2 10 31 14) (2 9 30 31) 
;;			  (1 2 29 13) (10 12 32 16)))
;;
;;(defparameter S2-1/2-13 '((1 33 13 17) (1 33 17 21) (1 33 21 25) (1 33 25 29) 
;;			  (1 33 29 13) (2 34 13 14) (2 34 14 31) (2 34 30 31) 
;;			  (2 34 29 30) (2 34 29 13) (3 35 13 17) (3 35 17 18) 
;;			  (3 35 18 15) (3 35 15 14) (3 35 14 13) (4 36 17 21) 
;;			  (4 36 21 22) (4 36 22 19) (4 36 19 18) (4 36 18 17)
;;			  (5 37 21 25) (5 37 25 26) (5 37 26 23) (5 37 23 22) 
;;			  (5 37 22 21) (6 38 25 29) (6 38 29 30) (6 38 30 27) 
;;			  (6 38 27 26) (6 38 26 25) (7 39 19 22) (7 39 22 23) 
;;			  (7 39 23 24) (7 39 24 20) (7 39 20 19) (8 40 23 26) 
;;			  (8 40 26 27) (8 40 27 28) (8 40 28 24) (8 40 24 23) 
;;			  (9 41 27 30) (9 41 30 31) (9 41 31 32) (9 41 32 28) 
;;			  (9 41 28 27) (10 42 31 14) (10 42 14 15) (10 42 15 16) 
;;			  (10 42 16 32) (10 42 32 31) (11 43 15 18) (11 43 18 19) 
;;			  (11 43 19 20) (11 43 20 16) (11 43 16 15) (12 44 16 20) 
;;			  (12 44 20 24) (12 44 24 28) (12 44 28 32) (12 44 32 16)))


(defun reset-spacetime ()
  "the state of the simulation after (reset-spacetime) is identical 
to the state after (load \"cdt2p1.lisp\")"
  ;; clear the hash tables
  (clrhash *2SIMPLEX->ID*)
  (clrhash *ID->2SIMPLEX*)
  (clrhash *ID->3SIMPLEX*)
  ;; reset the counters
  (setf *LAST-USED-2SXID* 0)
  (setf *LAST-USED-3SXID* 0)
  (setf *RECYCLED-3SX-IDS* '())
  (setf *LAST-USED-POINT* 0)
  ;; reset the ''bulk'' variables
  (setf N0 0)
  (setf N1-SL 0)
  (setf N1-TL 0)
  (setf N2-SL 0)
  (setf N2-TL 0)
  (setf N3-TL-31 0)
  (setf N3-TL-22 0)
  ;; reset the parameters
  (setf k0 0.0)
  (setf k3 0.0)
  (setf eps 0.02)
  (setf *a* 1.0)
  (setf *alpha* -1.0)
  (setf *k* 1.0)
  (setf *litL* 1.0)
  (setf CURRENT-MOVE-IDENTIFIER "UNKNOWN")
  (setf CURRENT-MOVE-NUMBER 0)
  (setf STOPOLOGY "unknown")
  (setf BCTYPE "unknown")
  (setf SAVE-EVERY-N-SWEEPS 10)
  (setf NUM-T 666666)
  (setf N-INIT 0)
  (setf NUM-SWEEPS 0)
  ;; reset the move markers
  (setf 26MARKER 0.0)
  (setf 23MARKER 0.0)
  (setf 44MARKER 0.0)
  (setf 32MARKER 0.0)
  (setf 62MARKER 0.0))
;; 2simplex
;; (type tmlo tmhi (p0 p1 p2))
;; type = 0,1,2,3 tm[lo|hi] = [lo|hi] spatial time slice pj = points, nj = neighbor that does not have pj

;; spatial-2simplex
;; (time (p0 p1 p2) (n0 n1 n2))

;; 3simplex
;; (type tmlo tmhi (n0 n1 n2 n3) (t0 t1 t2 t3))
;; type = 1,2,3 tm[lo|hi] - [lo|hi] spatial time slice
;; tj = id of the 2sx that does not have pj
;; nj = id of the 3sx that does not have pj

;;macro to decide whether or not to apply a modulo division, depending on
;;whether periodic BC's are in use
(defmacro bc-mod (num)
  `(if (string= BCTYPE "PERIODIC")
       (mod ,num NUM-T)
       ,num))

(defun make-2simplex (type tmlo tmhi p0 p1 p2)
  "makes and returns the id of the 2-simplex with the specified data. If a 2-simplex with points 
p0 p1 p2 already exists, the id of that simplex is returned"
  (let* ((2sx (list type tmlo tmhi (list p0 p1 p2)))
	 (2sxid (gethash 2sx *2SIMPLEX->ID*)))
    (unless 2sxid
      (setf 2sxid (next-2simplex-id))
      (setf (gethash 2sx *2SIMPLEX->ID*) 2sxid)
      (setf (gethash 2sxid *ID->2SIMPLEX*) 2sx))
    2sxid))

(defmacro get-2simplex (sxid) `(gethash ,sxid *ID->2SIMPLEX*))

(defmacro 2sx-type (2sx) `(first ,2sx))
(defmacro 2sx-tmlo (2sx) `(second ,2sx))
(defmacro 2sx-tmhi (2sx) `(third ,2sx)) 
(defmacro 2sx-points (2sx) `(fourth ,2sx))

(defmacro s2sx-time (s2sx) `(first ,s2sx))
(defmacro s2sx-points (s2sx) `(second ,s2sx))
(defmacro s2sx-sx2ids (s2sx) `(third ,s2sx))

(defun make-s2simplex (triangle-time triangle-points)
  (let ((stid (next-spatial-2simplex-id)))
    (setf (gethash stid *ID->SPATIAL-2SIMPLEX*) 
	  (list triangle-time (copy-list triangle-points) (list 0 0 0)))
    stid))
;; this version is used for loading the simplex data from file
(defun make-s2simplex-v2 (s2sxid s2sxtm p0 p1 p2 n0 n1 n2)
  (setf (gethash s2sxid *ID->SPATIAL-2SIMPLEX*)
	(list s2sxtm (list p0 p1 p2) (list n0 n1 n2))))
(defmacro get-s2simplex (stid) `(gethash ,stid *ID->SPATIAL-2SIMPLEX*))

(defmacro remove-2simplex (2sxid)
  `(let ((2sx (gethash ,2sxid *ID->2SIMPLEX*)))
     (remhash ,2sxid *ID->2SIMPLEX*)
     (remhash 2sx *2SIMPLEX->ID*)))

(defun remove-2simplices (2sxids)
  (dolist (2sxid 2sxids)
    (let ((2sx (gethash 2sxid *ID->2SIMPLEX*)))
      (remhash 2sxid *ID->2SIMPLEX*)
      (remhash 2sx *2SIMPLEX->ID*))))

(defun show-2simplex->id-store ()
  (maphash #'(lambda (2sx 2sxid) (format t "~A [~A]~%" 2sx 2sxid)) *2SIMPLEX->ID*))

(defun show-id->2simplex-store ()
  (maphash #'(lambda (2sxid 2sx) (format t "[~A] ~A~%" 2sxid 2sx)) *ID->2SIMPLEX*))

(defun connect-spatial-2simplices (st1id st2id)
  (let ((st1 nil) (st2 nil))
    (when (and (setf st1 (get-s2simplex st1id)) (setf st2 (get-s2simplex st2id)))
      (let* ((points1 (s2sx-points st1))
	     (points2 (s2sx-points st2))
	     (line (intersection points1 points2)))
	(when (= 2 (length line))
	  (let ((pos1 (position (first (set-difference points1 line)) points1))
		(pos2 (position (first (set-difference points2 line)) points2)))
	    (setf (nth pos1 (s2sx-sx2ids st1)) st2id)(setf (nth pos2 (s2sx-sx2ids st2)) st1id)))))))

(defun connect-spatial-2simplices-within-list (sx1ids)
  (for (n 0 (1- (length sx1ids)))
       (for (m (1+ n) (1- (length sx1ids)))
	    (connect-spatial-2simplices (nth n sx1ids) (nth m sx1ids)))))

(defun make-3simplex (type tmlo tmhi p0 p1 p2 p3)
  (let ((t0type nil) (t1type nil) (t2type nil) (t3type nil) (sx3id (next-3simplex-id)))
    (ecase type
      (1 (setf t0type 0) (setf t1type 1) (setf t2type 1)(setf t3type 1))
      (2 (setf t0type 1) (setf t1type 1) (setf t2type 2)(setf t3type 2))
      (3 (setf t0type 2) (setf t1type 2) (setf t2type 2)(setf t3type 3)))
    (setf (gethash sx3id *ID->3SIMPLEX*)
	  (list type tmlo tmhi
		(list p0 p1 p2 p3)
		(list 0 0 0 0)
		(list (make-2simplex t0type tmlo tmhi p1 p2 p3)
		      (make-2simplex t1type tmlo tmhi p0 p2 p3)
		      (make-2simplex t2type tmlo tmhi p0 p1 p3)
		      (make-2simplex t3type tmlo tmhi p0 p1 p2))))
    sx3id))

;; same as above except the points are "packed" into a list; useful during the moves, when the points
;; of the simplex are computed via append / unions / intersections in the form of a list
(defun make-3simplex-v2 (type tmlo tmhi pts)
  (let ((t0type nil) (t1type nil) (t2type nil) (t3type nil) (sx3id (next-3simplex-id)))
    (ecase type
      (1 (setf t0type 0) (setf t1type 1) (setf t2type 1)(setf t3type 1))
      (2 (setf t0type 1) (setf t1type 1) (setf t2type 2)(setf t3type 2))
      (3 (setf t0type 2) (setf t1type 2) (setf t2type 2)(setf t3type 3)))
    (setf (gethash sx3id *ID->3SIMPLEX*)
	  (list type tmlo tmhi
		(copy-list pts)
		(list 0 0 0 0)
		(list (make-2simplex t0type tmlo tmhi (nth 1 pts) (nth 2 pts) (nth 3 pts))
		      (make-2simplex t1type tmlo tmhi (nth 0 pts) (nth 2 pts) (nth 3 pts))
		      (make-2simplex t2type tmlo tmhi (nth 0 pts) (nth 1 pts) (nth 3 pts))
		      (make-2simplex t3type tmlo tmhi (nth 0 pts) (nth 1 pts) (nth 2 pts)))))
    sx3id))

;; this version is used only during initialization. If periodic b.c. are specified, it adjusts the
;; points on the final time slice, since the t=T slice is identified with t=0 slice.
(defun make-3simplex-v3 (type tmlo tmhitmp p0tmp p1tmp p2tmp p3tmp)
  (let ((t0type nil) (t1type nil) (t2type nil) (t3type nil) (sx3id (next-3simplex-id))
	(p0 p0tmp) (p1 p1tmp) (p2 p2tmp) (p3 p3tmp) (tmhi tmhitmp))
    (when (and (string= BCTYPE "PERIODIC") (= NUM-T tmhitmp))
      (setf tmhi 0)
      (cond ((= 1 type)
	     (decf p1 (* N0-PER-SLICE NUM-T)) 
	     (decf p2 (* N0-PER-SLICE NUM-T)) 
	     (decf p3 (* N0-PER-SLICE NUM-T)))
	    ((= 2 type)
	     (decf p2 (* N0-PER-SLICE NUM-T)) 
	     (decf p3 (* N0-PER-SLICE NUM-T)))
	    ((= 3 type)
	     (decf p3 (* N0-PER-SLICE NUM-T)))))
    (ecase type
      (1 (setf t0type 0) (setf t1type 1) (setf t2type 1)(setf t3type 1))
      (2 (setf t0type 1) (setf t1type 1) (setf t2type 2)(setf t3type 2))
      (3 (setf t0type 2) (setf t1type 2) (setf t2type 2)(setf t3type 3)))

    ;;set last used point if a new point is used
    (setf *LAST-USED-POINT* (max *LAST-USED-POINT* p0 p1 p2 p3))

    (setf (gethash sx3id *ID->3SIMPLEX*)
	  (list type tmlo tmhi
		(list p0 p1 p2 p3)
		(list 0 0 0 0)
		(list (make-2simplex t0type tmlo tmhi p1 p2 p3)
		      (make-2simplex t1type tmlo tmhi p0 p2 p3)
		      (make-2simplex t2type tmlo tmhi p0 p1 p3)
		      (make-2simplex t3type tmlo tmhi p0 p1 p2))))))

;; this version is used for loading the simplex data from file
(defun make-3simplex-v4 (type tmlo tmhi p0 p1 p2 p3 n0 n1 n2 n3 sx3id)
  (let ((t0type nil) (t1type nil) (t2type nil) (t3type nil))
    (ecase type
      (1 (setf t0type 0) (setf t1type 1) (setf t2type 1)(setf t3type 1))
      (2 (setf t0type 1) (setf t1type 1) (setf t2type 2)(setf t3type 2))
      (3 (setf t0type 2) (setf t1type 2) (setf t2type 2)(setf t3type 3)))
    (setf (gethash sx3id *ID->3SIMPLEX*)
	  (list type tmlo tmhi
		(list p0 p1 p2 p3)
		(list n0 n1 n2 n3)
		(list (make-2simplex t0type tmlo tmhi p1 p2 p3)
		      (make-2simplex t1type tmlo tmhi p0 p2 p3)
		      (make-2simplex t2type tmlo tmhi p0 p1 p3)
		      (make-2simplex t3type tmlo tmhi p0 p1 p2))))))

;; a replacement for v2
(defun make-3simplex-v5 (simplex-data)
  (let ((type (first simplex-data))
	(tmlo (second simplex-data))
	(tmhi (third simplex-data))
	(pts (fourth simplex-data))
	(t0type nil) (t1type nil) (t2type nil) (t3type nil) (sx3id (next-3simplex-id)))
    (ecase type
      (1 (setf t0type 0) (setf t1type 1) (setf t2type 1)(setf t3type 1))
      (2 (setf t0type 1) (setf t1type 1) (setf t2type 2)(setf t3type 2))
      (3 (setf t0type 2) (setf t1type 2) (setf t2type 2)(setf t3type 3)))
    (setf (gethash sx3id *ID->3SIMPLEX*)
	  (list type tmlo tmhi
		(copy-list pts)
		(list 0 0 0 0)
		(list (make-2simplex t0type tmlo tmhi (nth 1 pts) (nth 2 pts) (nth 3 pts))
		      (make-2simplex t1type tmlo tmhi (nth 0 pts) (nth 2 pts) (nth 3 pts))
		      (make-2simplex t2type tmlo tmhi (nth 0 pts) (nth 1 pts) (nth 3 pts))
		      (make-2simplex t3type tmlo tmhi (nth 0 pts) (nth 1 pts) (nth 2 pts)))))
    sx3id))

;; simplex-data-list = ((typ tmlo tmhi (p0 p1 p2 p3)) (typ tmlo tmhi (p0 p1 p2 p3))...)
;; the ids of the simplices are returned
(defun make-3simplices-in-bulk (simplex-data-list)
  (let ((3sxids nil))
    (dolist (simplex-data simplex-data-list)
      (push (make-3simplex-v5 simplex-data) 3sxids))
    3sxids))

(defmacro 3sx-type (sx) `(nth 0 ,sx))
(defmacro 3sx-tmlo (sx) `(nth 1 ,sx))
(defmacro 3sx-tmhi (sx) `(nth 2 ,sx))
(defmacro 3sx-points (sx) `(nth 3 ,sx))
(defmacro 3sx-sx3ids (sx) `(nth 4 ,sx))
(defmacro 3sx-sx2ids (sx) `(nth 5 ,sx))
(defmacro 3sx-lopts (sx) `(subseq (3sx-points ,sx) 0 (3sx-type ,sx)))
(defmacro 3sx-hipts (sx) `(subseq (3sx-points ,sx) (3sx-type ,sx)))

(defmacro get-3simplex (sxid)
  `(gethash ,sxid *ID->3SIMPLEX*))
(defmacro remove-3simplex (3sxid)
  `(progn
     (remhash ,3sxid *ID->3SIMPLEX*)
     (recycle-3simplex-id ,3sxid)))
(defmacro remove-3simplices (3sxids)
  `(dolist (3sxid ,3sxids)
     (remhash 3sxid *ID->3SIMPLEX*)
     (recycle-3simplex-id 3sxid)))
(defun show-id->3simplex-store ()
  (maphash #'(lambda (3sxid 3sx) (format t "[~A] ~A~%" 3sxid 3sx)) *ID->3SIMPLEX*))

(defmacro nth-point (sx n)
  `(nth ,n (3sx-points ,sx)))

(defun connect-3simplices (sx1id sx2id)
  (let ((sx1 nil) (sx2 nil))
    (when (and (setf sx1 (get-3simplex sx1id)) (setf sx2 (get-3simplex sx2id)))
      (let ((2sxlinkid (intersection (3sx-sx2ids sx1) (3sx-sx2ids sx2))))
	(when (= 1 (length 2sxlinkid))
	  (let ((pos1 (position (first 2sxlinkid) (3sx-sx2ids sx1)))
		(pos2 (position (first 2sxlinkid) (3sx-sx2ids sx2))))
	    (setf (nth pos1 (3sx-sx3ids sx1)) sx2id) (setf (nth pos2 (3sx-sx3ids sx2)) sx1id)))))))

(defun connect-3simplices-within-list (sx1ids)
  (for (n 0 (1- (length sx1ids)))
       (for (m (1+ n) (1- (length sx1ids)))
	    (connect-3simplices (nth n sx1ids) (nth m sx1ids)))))

(defun connect-3simplices-across-lists (sx1ids sx2ids)
  (dolist (sx1id sx1ids)
    (dolist (sx2id sx2ids)
      (connect-3simplices sx1id sx2id))))

(defmacro 3simplices-connected? (sxid1 sxid2)
  `(let ((sx1 nil) (sx2 nil))
     (and (setf sx1 (get-3simplex ,sxid1)) (setf sx2 (get-3simplex ,sxid2))
	  (find ,sxid1 (3sx-sx3ids sx2)) (find ,sxid2 (3sx-sx3ids sx1)))))

(defun get-simplices-in-sandwich (tlo thi)
  (let ((sxids '()))
    (maphash #'(lambda (id sx)
		 (when (and (= (3sx-tmlo sx) (bc-mod tlo)) 
			    (= (3sx-tmhi sx) (bc-mod thi)))
		   (push id sxids)))
	     *ID->3SIMPLEX*)
    sxids))

(defun get-simplices-in-sandwich-of-type (tlo thi typ)
  (let ((sxids '()))
    (maphash #'(lambda (id sx)
		 (when (and (= (3sx-tmlo sx) (bc-mod tlo)) 
			    (= (3sx-tmhi sx) (bc-mod thi))
			    (= (3sx-type sx) typ))
		   (push id sxids)))
	     *ID->3SIMPLEX*)
    sxids))

(defun get-2simplices-in-sandwich-of-type (tlo thi typ)
  (let ((sxids '()))
    (maphash #'(lambda (id sx)
		 (when (and (= (2sx-tmlo sx) (bc-mod tlo)) 
			    (= (2sx-tmhi sx) (bc-mod thi))
			    (= (2sx-type sx) typ))
		   (push id sxids)))
	     *ID->2SIMPLEX*)
    sxids))

;; returns (1ids 2ids 3ids) where 1ids is a list of (1,3) ids in the sandwich etc.
(defun get-simplices-in-sandwich-ordered-by-type (tlo thi)
  (let ((1ids nil) (2ids nil) (3ids nil))
    (maphash #'(lambda (id sx)
		 (when (and (= (3sx-tmlo sx) (bc-mod tlo)) 
			    (= (3sx-tmhi sx) (bc-mod thi)))
		   (ecase (3sx-type sx)
		     (1 (push id 1ids))
		     (2 (push id 2ids))
		     (3 (push id 3ids)))))
	     *ID->3SIMPLEX*)
    (values 1ids 2ids 3ids)))

;;define macro to help weed out fictitious simplices added for open boundaries
(defmacro is-real-simplex (sx)
  `(and (>= (3sx-tmlo ,sx) 0) (<= (3sx-tmhi ,sx) NUM-T)))

(defun get-simplices-of-type (typ)
  (let ((sxids '()))
    (maphash #'(lambda (id sx)
		 (if (and (is-real-simplex sx) (= (3sx-type sx) typ))
		     (push id sxids)))
	     *ID->3SIMPLEX*)
    sxids))

;;function to grab even the fake simplices beyond the boundaries
(defun get-real-and-fake-simplices-of-type (typ)
  (let ((sxids '()))
    (maphash #'(lambda (id sx)
		 (if (= (3sx-type sx) typ)
		     (push id sxids)))
	     *ID->3SIMPLEX*)
    sxids))

(defun count-simplices-of-type (typ)
  (let ((count 0))
    (maphash #'(lambda (id sx)
		 (declare (ignore id))
		 (if (and (is-real-simplex sx) (= (3sx-type sx) typ))
		     (incf count)))
	     *ID->3SIMPLEX*)
    count))

(defun count-simplices-in-sandwich (tlo thi)
  (let ((count 0))
    (maphash #'(lambda (id sx)
		 (declare (ignore id))
		 (when (and (= (3sx-tmlo sx) (bc-mod tlo)) 
			    (= (3sx-tmhi sx) (bc-mod thi)))
		     (incf count)))
	     *ID->3SIMPLEX*)
    count))

(defun count-simplices-of-all-types ()
  (let ((1count 0) (2count 0) (3count 0))
    (maphash #'(lambda (id sx)
		 (declare (ignore id))
		 (when (is-real-simplex sx)
		   (ecase (3sx-type sx)
		     (1 (incf 1count))
		     (2 (incf 2count))
		     (3 (incf 3count)))))
	     *ID->3SIMPLEX*)
    (list 1count 2count 3count (+ 1count 2count 3count))))

(defun count-boundary-vs-bulk ()
  (let ((first-13 0) (last-13 0) (bulk-13 0)
	(first-22 0) (last-22 0) (bulk-22 0)
	(first-31 0) (last-31 0) (bulk-31 0))
    (maphash #'(lambda (id sx)
		 (declare (ignore id))
		 (let* ((ty (3sx-type sx))
			(tl (3sx-tmlo sx))
			(th (3sx-tmhi sx))
			(in-first (= tl 0))
			(in-last  (= th NUM-T))
			(outside  (or (= tl -1) (= tl NUM-T)))
			(in-bulk  (not (or in-first in-last outside))))
		   (cond
		     ((and in-first (= ty 1)) (incf first-13))
		     ((and in-first (= ty 2)) (incf first-22))
		     ((and in-first (= ty 3)) (incf first-31))
		     ((and in-bulk  (= ty 1)) (incf bulk-13))
		     ((and in-bulk  (= ty 2)) (incf bulk-22))
		     ((and in-bulk  (= ty 3)) (incf bulk-31))
		     ((and in-last  (= ty 1)) (incf last-13))
		     ((and in-last  (= ty 2)) (incf last-22))
		     ((and in-last  (= ty 3)) (incf last-31)))))
	     *ID->3SIMPLEX*)
    (list first-13 first-22 first-31
	  bulk-13  bulk-22  bulk-31
	  last-13  last-22  last-31
	  (+ first-13 first-22 first-31
	     bulk-13 bulk-22 bulk-31
	     last-13 last-22 last-31))))

(defun count-simplices-in-sandwich-of-type (tlo thi typ)
  (let ((count 0))
    (maphash #'(lambda (id sx)
		 (declare (ignore id))
		 (when (and (= (3sx-tmlo sx) (bc-mod tlo)) 
			    (= (3sx-tmhi sx) (bc-mod thi))
			    (= (3sx-type sx) typ))
		   (incf count)))
	     *ID->3SIMPLEX*)
    count))

;;function to count the number of points in a particular time slice
(defun count-points-at-time (t0)

  ;;for all but the first time slice, we can get the upper points from all
  ;;simplicies in the (1- t0)/t0 time sandwich.  otherwise, we need to get 
  ;;the lower points of the first sandwich.

  (let ((list-of-points-with-duplicates () )
	(previous-element 0)
	(count 0))
    (if (= t0 0)
	(dolist (sxid (get-simplices-in-sandwich 0 1))
	  (dolist (i (3sx-lopts (get-3simplex sxid)))
	    (push i list-of-points-with-duplicates)))
	(dolist (sxid (get-simplices-in-sandwich (1- t0) t0))
	  (dolist (i (3sx-hipts (get-3simplex sxid)))
	    (push i list-of-points-with-duplicates))))

    ;;sorting the list allows me to count the number of unique points faster
    (dolist (i (sort list-of-points-with-duplicates #'<))
      (when (not (= previous-element i))
	(incf count)
	(setf previous-element i)))
    count))

;;function to count the number of timelike links in a sandwich
(defun count-timelike-links-in-sandwich (t0 t1)
 
  ;;approach: get all of the simplices in the sandwich, then repeatedly
  ;;perform set unions with the links from each simplex
  
  (let ((list-of-links () ))
    (dolist (sxid (get-simplices-in-sandwich t0 t1))
      (let* ((sx (get-3simplex sxid))
	     (lopts (3sx-lopts sx))
	     (hipts (3sx-hipts sx))
	     (sx-tl-links (let ((retval ()))
			    (dolist (lopt lopts)
			      (dolist (hipt hipts)
				(push (list lopt hipt) retval)))
			    retval)))
	(setf list-of-links (union list-of-links sx-tl-links 
				   :test #'(lambda (x y) (not (set-difference x y)))))))
    (length list-of-links)))

;;count the number of spacelike triangles at a certain time
(defun count-spacelike-triangles-at-time (t0)

  ;;must treat one end as a special case; choosing to treat
  ;;time 0 specially. number of triangles is just related to the
  ;;number of type 1/3 simplices in nieghboring sandwiches

  (if (= t0 0)
      (count-simplices-in-sandwich-of-type 0 1 3)
      (count-simplices-in-sandwich-of-type (1- t0) t0 1)))

;;count the number of spacelike links at a particular time, using the euler characteristic
;;and the numbers of triangles and points
(defun count-spacelike-links-at-time (t0)

  (let* ((chi (euler-char))
	 (n0  (count-points-at-time t0))
	 (n2  (count-spacelike-triangles-at-time t0)))

    ;;  (chi = n0 - n1 + n2)  =>  (n1 = n0 + n2 - chi)
    (- (+ n0 n2) chi)))
				    
;;count the number of timelike triangles in a particular sandwich
(defun count-timelike-triangles-in-sandwich (t0 t1)
  
  ;;similar approach to counting timelike links, except sets of three points
  ;;are collected and counted

  (let ((list-of-triangles () ))
    (dolist (sxid (get-simplices-in-sandwich t0 t1))
      (let* ((sx (get-3simplex sxid))
	     (ty (3sx-type sx))
	     (pts (3sx-points sx))

	     (sx-tl-triangles
	      (case ty
		(1 (list (list (first pts)  (second pts) (third pts))
			 (list (first pts)  (second pts) (fourth pts))
			 (list (first pts)  (third pts)  (fourth pts))))
		(2 (list (list (first pts)  (third pts)  (fourth pts))
			 (list (second pts) (third pts)  (fourth pts))
			 (list (first pts)  (second pts) (third pts))
			 (list (first pts)  (second pts) (fourth pts))))
		(3 (list (list (fourth pts) (first pts)  (second pts))
			 (list (fourth pts) (first pts)  (third pts))
			 (list (fourth pts) (second pts) (third pts)))))))

	(setf list-of-triangles (union list-of-triangles sx-tl-triangles
				       :test #'(lambda (x y) (not (set-difference x y)))))))
    (length list-of-triangles)))


;;(defun connect-simplices-in-sandwich (tlo thi)
;;(connect-3simplices-within-list (get-simplices-in-sandwich tlo thi)))

;; in a given sandwich
;; (1,3) can be connected to a (2,2) and cannot be connected to a (3,1)
;; a (2,2) can be connected to a (1,3) and a (3,1)
;; a (3,2) can be connected to a (2,2) and cannot be connected to a (1,3)
(defun connect-simplices-in-sandwich (tlo thi)
  (multiple-value-bind (1ids 2ids 3ids) (get-simplices-in-sandwich-ordered-by-type tlo thi)
    (connect-3simplices-across-lists 1ids 2ids)
    (connect-3simplices-across-lists 2ids 3ids)
    (connect-3simplices-within-list 1ids)
    (connect-3simplices-within-list 2ids)
    (connect-3simplices-within-list 3ids)))

(defun connect-simplices-in-adjacent-sandwiches (tl tm th)
  (connect-3simplices-across-lists 
   (get-simplices-in-sandwich-of-type tl tm 1)
   (get-simplices-in-sandwich-of-type tm th 3)))

(defun check-13-and-31 (tlo thi)
  (let ((13ids (get-simplices-in-sandwich-of-type tlo thi 1))
	(31ids (get-simplices-in-sandwich-of-type tlo thi 3))
	(problem-ids '()))
    (dolist (s13 13ids)
      (dolist (d13 13ids)
	(when (and (/= s13 d13) (set-equal? (subseq (3sx-points (get-3simplex s13)) 1)
					    (subseq (3sx-points (get-3simplex d13)) 1)))
	  (push (list s13 d13) problem-ids))))
    (dolist (s31 31ids)
      (dolist (d31 31ids)
	(when (and (/= s31 d31) (set-equal? (subseq (3sx-points (get-3simplex s31)) 0 3)
					    (subseq (3sx-points (get-3simplex d31)) 0 3)))
	  (push (list s31 d31) problem-ids))))
    problem-ids))

(defun check-all-slices-for-problem-simplices ()
  (for (ts 0 (- NUM-T 1))
       (format t "slice ~A has ~A problem simplices~%" ts (check-13-and-31 ts (1+ ts)))
       (finish-output)))

(defun check-all-slices-for-simplices-with-missing-neighbors ()
  (let ((problem-ids '()))
    (maphash #'(lambda (id sx)
		 (for (n 0 3)
		   (if (= 0 (nth n (3sx-sx3ids sx)))
		       (push id problem-ids))))
	     *ID->3SIMPLEX*)
    problem-ids))

;; if the 3-simplices are connected, returns the id of the linking 2-simplex else returns 0
(defmacro link-id (sxid1 sxid2)
  `(let ((sx1 nil) (sx2 nil) (link nil))
     (if (and (setf sx1 (get-3simplex ,sxid1)) 
	      (setf sx2 (get-3simplex ,sxid2))
	      (setf link (intersection (3sx-sx2ids sx2) (3sx-sx2ids sx1))))
	 (first link)
	 0)))

(defun neighbors-of-type (sx type)
  (let ((nbors nil)
	(nsx nil)
	(nids (3sx-sx3ids sx)))
    (for (n 0 3)
      (when (and (setf nsx (get-3simplex (nth n nids))) (= type (3sx-type nsx)))
	(pushnew (nth n nids) nbors)))
    nbors))

(defun save-spacetime-to-file (outfile)
  (format outfile "~A ~A ~A ~A ~A ~A ~A ~A ~A ~A ~A ~A ~A ~A ~A ~A ~A~%" 
	  BCTYPE STOPOLOGY NUM-T N-INIT *LAST-USED-POINT* *LAST-USED-3SXID* 
	  N0 N1-SL N1-TL N2-SL N2-TL N3-TL-31 N3-TL-22 eps k0 k3 *alpha*)
  (maphash #'(lambda (k v)
	       (format outfile "~A ~A ~A ~A ~A ~A ~A ~A ~A ~A ~A ~A~%" 
		       (3sx-type v) (3sx-tmlo v) (3sx-tmhi v)
		       (nth-point v 0) (nth-point v 1) (nth-point v 2) (nth-point v 3)
		       (nth 0 (3sx-sx3ids v)) (nth 1 (3sx-sx3ids v)) 
		       (nth 2 (3sx-sx3ids v)) (nth 3 (3sx-sx3ids v)) k))
	   *ID->3SIMPLEX*))

(defun save-s2simplex-data-to-file (outfile)
  (maphash #'(lambda (k v)
	       (let ((pts (s2sx-points v))
		     (nbors (s2sx-sx2ids v)))
		 (format outfile "~A ~A ~A ~A ~A ~A ~A ~A~%"
			 k (s2sx-time v) (nth 0 pts) (nth 1 pts) (nth 2 pts) (nth 0 nbors) (nth 1 nbors)
			 (nth 2 nbors))))
	   *ID->SPATIAL-2SIMPLEX*))

(defun parse-parameters-line (line)
  (with-input-from-string (s line)
    (let ((data (loop
		   :for num := (read s nil nil)
		   :while num
		   :collect num)))
      (setf BCTYPE (nth 0 data)) (setf STOPOLOGY (nth 1 data))
      (setf NUM-T (nth 2 data)) (setf N-INIT (nth 3 data))
      (setf *LAST-USED-POINT* (nth 4 data)) (setf *LAST-USED-3SXID* (nth 5 data))
      (setf N0 (nth 6 data)) (setf N1-SL (nth 7 data)) (setf N1-TL (nth 8 data))
      (setf N2-SL (nth 9 data)) (setf N2-TL (nth 10 data)) (setf N3-TL-31 (nth 11 data))
      (setf N3-TL-22 (nth 12 data)) (setf eps (nth 13 data)) 
      (set-k0-k3-alpha (nth 14 data) (nth 15 data) (nth 16 data)))))

(defun parse-simplex-data-line (line)
  (with-input-from-string (s line)
    (let ((data (loop
		   :for num := (read s nil nil)
		   :while num
		   :collect num)))
      (make-3simplex-v4 (nth 0 data) (nth 1 data) (nth 2 data) (nth 3 data) 
			(nth 4 data) (nth 5 data) (nth 6 data) (nth 7 data)
			(nth 8 data) (nth 9 data) (nth 10 data) (nth 11 data)))))

(defun load-spacetime-from-file (infile)
  (parse-parameters-line (read-line infile nil))
  (loop for line = (read-line infile nil)
     while line do (parse-simplex-data-line line)))

(defun parse-s2simplex-data-line (line)
  (with-input-from-string (s line)
    (let ((data (loop
		   :for num := (read s nil nil)
		   :while num
		   :collect num)))
      (make-s2simplex-v2 (nth 0 data) (nth 1 data) (nth 2 data) (nth 3 data) (nth 4 data)
			 (nth 5 data) (nth 6 data) (nth 7 data)))))

(defun load-s2simplex-data-from-file (infile)
  (clrhash *ID->SPATIAL-2SIMPLEX*)
  (loop for line = (read-line infile nil)
     while line do (parse-s2simplex-data-line line)));; try-a->b methods returns the following list, IFF the move can be successfully made
;; (new3sxids nbors old3sxids old2sxids fvector bvector)
;;

(defun 2plus1move (sxdata) ;;new3sxdata 3sxnbors old3sxids old2sxids fvector)
  (let ((new3sxids (make-3simplices-in-bulk (first sxdata))))
    (connect-3simplices-within-list new3sxids)
    (connect-3simplices-across-lists new3sxids (second sxdata))
    (remove-3simplices (third sxdata))
    (remove-2simplices (fourth sxdata))
    (update-f-vector (fifth sxdata))
    (update-b-vector (sixth sxdata))))


(defun 2->6-subcomplex (sxid)
  (let ((subcmplx nil)
	(sx nil))
    (when (setf sx (get-3simplex sxid))
      (cond ((= 1 (3sx-type sx))
	     (when (/= 0 (nth 0 (3sx-sx3ids sx)))
	       (push (list sxid (nth 0 (3sx-sx3ids sx))) subcmplx)))
	    ((= 3 (3sx-type sx))
	     (when (/= 0 (nth 3 (3sx-sx3ids sx)))
	       (push (list (nth 3 (3sx-sx3ids sx)) sxid) subcmplx)))))
    subcmplx))
				  
(defun try-2->6 (sxid)
  (dolist (curr (2->6-subcomplex sxid))
    (let* ((sx13 (get-3simplex (first curr)))
	   (sx31 (get-3simplex (second curr)))
	   (old-internal-triangle (nth 0 (3sx-sx2ids sx13)))
	   (nbors (set-difference (union (3sx-sx3ids sx13) (3sx-sx3ids sx31)) curr))
	   (lopt (nth-point sx13 0))
	   (hipt (nth-point sx31 3))
	   (bigtr (2sx-points (get-2simplex old-internal-triangle)))
	   (13tmlo (3sx-tmlo sx13)) (13tmhi (3sx-tmhi sx13))
	   (31tmlo (3sx-tmlo sx31)) (31tmhi (3sx-tmhi sx31))
	   (newpt (next-pt))
	   (newsxdata (list (list 1 13tmlo 13tmhi (list lopt newpt (first bigtr) (second bigtr)))
			    (list 1 13tmlo 13tmhi (list lopt newpt (second bigtr) (third bigtr)))
			    (list 1 13tmlo 13tmhi (list lopt newpt (third bigtr) (first bigtr)))
			    (list 3 31tmlo 31tmhi (list (first bigtr) (second bigtr) newpt hipt))
			    (list 3 31tmlo 31tmhi (list (second bigtr) (third bigtr) newpt hipt))
			    (list 3 31tmlo 31tmhi (list (third bigtr) (first bigtr) newpt hipt)))))

      (return-from try-2->6 (list newsxdata nbors curr (list old-internal-triangle) (DF26 sxid) (DB26 sxid))))))

(defun 6->2-subcomplex (sxid)
  "returns a list of the form ((13id1 13id2 13id3 31id3 31id2 31id1)...)"
  (let ((sx nil)
	(subcmplx nil))
    (when (setf sx (get-3simplex sxid))
      (cond ((= 1 (3sx-type sx))
	     (let ((31id (nth 0 (3sx-sx3ids sx)))
		   (31sx nil))
	       (when (setf 31sx (get-3simplex 31id))
		 (let ((13nbors (neighbors-of-type sx 1)))
		   (unless (< (length 13nbors) 2)
		     (do-tuples/c (currid nextid) 13nbors
		       (let ((curr nil) (next nil))
			 (when (and (setf curr (get-3simplex currid)) (setf next (get-3simplex nextid))
				    (3simplices-connected? currid nextid)
				    (3simplices-connected? (nth 0 (3sx-sx3ids curr))
							   (nth 0 (3sx-sx3ids next)))
				    (3simplices-connected? (nth 0 (3sx-sx3ids curr)) 31id)
				    (3simplices-connected? (nth 0 (3sx-sx3ids next)) 31id))
			   (pushnew (list sxid currid nextid 
					  (nth 0 (3sx-sx3ids next)) 
					  (nth 0 (3sx-sx3ids curr))
					  31id)
				    subcmplx :test #'set-equal?)))))))))
	    ((= 3 (3sx-type sx))
	     (let ((13id (nth 3 (3sx-sx3ids sx)))
		   (13sx nil))
	       (when (setf 13sx (get-3simplex 13id))
		 (let ((31nbors (neighbors-of-type sx 3)))
		   (unless (< (length 31nbors) 2)
		     (do-tuples/c (currid nextid) 31nbors
		       (let ((curr nil) (next nil))
			 (when (and (setf curr (get-3simplex currid)) (setf next (get-3simplex nextid))
				    (3simplices-connected? currid nextid)
				    (3simplices-connected? (nth 3 (3sx-sx3ids curr))
							   (nth 3 (3sx-sx3ids next)))
				    (3simplices-connected? (nth 3 (3sx-sx3ids curr)) 13id)
				    (3simplices-connected? (nth 3 (3sx-sx3ids next)) 13id))
			   (pushnew (list 13id (nth 3 (3sx-sx3ids next)) (nth 3 (3sx-sx3ids curr))
					  currid nextid sxid) 
				    subcmplx :test #'set-equal?)))))))))))
    subcmplx))
	    
(defun try-6->2 (sxid)
  (let ((subcmplx (6->2-subcomplex sxid))
	(old-internal-triangles nil)
	(new-internal-triangle nil)
	(nbors nil)
	(newsxdata nil)
	(lopt nil)
	(hipt nil)
	(13tmlo nil) (13tmhi nil) (31tmlo nil) (31tmhi nil))
    (unless (null subcmplx)
      (dolist (curr subcmplx)
	(setf old-internal-triangles (list (link-id (first curr) (sixth curr))
					   (link-id (first curr) (second curr))
					   (link-id (first curr) (third curr))
					   (link-id (second curr) (third curr))
					   (link-id (second curr) (fifth curr))
					   (link-id (third curr) (fourth curr))
					   (link-id (fourth curr) (fifth curr))
					   (link-id (fourth curr) (sixth curr))
					   (link-id (fifth curr) (sixth curr))))
	(setf nbors (set-difference (unions (3sx-sx3ids (get-3simplex (first curr)))
					    (3sx-sx3ids (get-3simplex (second curr)))
					    (3sx-sx3ids (get-3simplex (third curr)))
					    (3sx-sx3ids (get-3simplex (fourth curr)))
					    (3sx-sx3ids (get-3simplex (fifth curr)))
					    (3sx-sx3ids (get-3simplex (sixth curr))))
				    (list 0 (first curr) (second curr) (third curr) 
					  (fourth curr) (fifth curr) (sixth curr))))
	(setf 13tmlo (3sx-tmlo (get-3simplex (first curr))))
	(setf 13tmhi (3sx-tmhi (get-3simplex (first curr))))
	(setf 31tmlo (3sx-tmlo (get-3simplex (sixth curr))))
	(setf 31tmhi (3sx-tmhi (get-3simplex (sixth curr))))
	(setf lopt (nth-point (get-3simplex (first curr)) 0))
	(setf hipt (nth-point (get-3simplex (sixth curr)) 3))
	(setf new-internal-triangle 
	      (list 0 13tmlo 13tmhi
		    (set-difference 
		     (unions (2sx-points (get-2simplex (first old-internal-triangles)))
			     (2sx-points (get-2simplex (fifth old-internal-triangles)))
			     (2sx-points (get-2simplex (sixth old-internal-triangles))))
		     (intersections (2sx-points (get-2simplex (first old-internal-triangles)))
				    (2sx-points (get-2simplex (fifth old-internal-triangles)))
				    (2sx-points (get-2simplex (sixth old-internal-triangles)))))))
	(unless (gethash new-internal-triangle *2SIMPLEX->ID*)
	  (setf newsxdata (list (list 1 13tmlo 13tmhi (cons lopt (2sx-points new-internal-triangle))) 
				(list 3 31tmlo 31tmhi (append (2sx-points new-internal-triangle) (list hipt)))))  
	  (return-from try-6->2 (list newsxdata nbors curr old-internal-triangles (DF62 sxid) (DB62 sxid))))))))

(defun 4->4-subcomplex (sxid)
  "returns a list of the form ((13id1 13id2 31id2 31id1)...)"
  (let ((sx nil)
	(subcmplx nil))
    (when (setf sx (get-3simplex sxid))
      (cond ((= 1 (3sx-type sx))
	     (let ((31id (nth 0 (3sx-sx3ids sx))) (31sx nil))
	       (when (setf 31sx (get-3simplex 31id))
		 (let ((13nbors (neighbors-of-type sx 1)))
		   (dolist (13nbor 13nbors)
		     (when (3simplices-connected? (nth 0 (3sx-sx3ids (get-3simplex 13nbor))) 31id)
		       (pushnew (list sxid 13nbor (nth 0 (3sx-sx3ids (get-3simplex 13nbor))) 31id)
				subcmplx :test #'set-equal?)))))))
	    ((= 3 (3sx-type sx))
	     (let ((13id (nth 3 (3sx-sx3ids sx))) (13sx nil))
	       (when (setf 13sx (get-3simplex 13id))
		 (let ((31nbors (neighbors-of-type sx 3)))
		   (dolist (31nbor 31nbors)
		     (when (3simplices-connected? (nth 3 (3sx-sx3ids (get-3simplex 31nbor))) 13id)
		       (pushnew (list 13id (nth 3 (3sx-sx3ids (get-3simplex 31nbor))) 31nbor sxid)
				subcmplx :test #'set-equal?)))))))))
    subcmplx))

(defun try-4->4 (sxid)
  (let ((subcmplx (4->4-subcomplex sxid))
	(old-internal-triangles nil)
	(new-internal-sl-triangle-1 nil) (new-internal-sl-triangle-2 nil)
	(new-internal-tl-triangle-1 nil) (new-internal-tl-triangle-2 nil)
	(shared nil) (unshared nil) (nbors nil) (newsxdata nil) (lopt nil) (hipt nil)
	(13tmlo nil) (13tmhi nil) (31tmlo nil) (31tmhi nil))
    (unless (null subcmplx)
      (dolist (curr subcmplx)
	(setf old-internal-triangles (list (link-id (first curr) (fourth curr)) ;; spacelike
					   (link-id (second curr) (third curr)) ;; spacelike
					   (link-id (first curr) (second curr)) ;; timelike
					   (link-id (third curr) (fourth curr)))) ;; timelike
	(setf 13tmlo (3sx-tmlo (get-3simplex (first curr))))
	(setf 13tmhi (3sx-tmhi (get-3simplex (first curr))))
	(setf 31tmlo (3sx-tmlo (get-3simplex (fourth curr))))
	(setf 31tmhi (3sx-tmhi (get-3simplex (fourth curr))))
	(setf lopt (nth-point (get-3simplex (first curr)) 0))
	(setf hipt (nth-point (get-3simplex (fourth curr)) 3))
	(setf nbors (set-difference (unions (3sx-sx3ids (get-3simplex (first curr)))
					    (3sx-sx3ids (get-3simplex (second curr)))
					    (3sx-sx3ids (get-3simplex (third curr)))
					    (3sx-sx3ids (get-3simplex (fourth curr))))
				    (list 0 (first curr) (second curr) (third curr) (fourth curr)))) 
	(setf shared (intersection (2sx-points (get-2simplex (first old-internal-triangles)))
				   (2sx-points (get-2simplex (second old-internal-triangles)))))
	(setf unshared (set-exclusive-or (2sx-points (get-2simplex (first old-internal-triangles)))
					 (2sx-points (get-2simplex (second old-internal-triangles)))))
	(setf new-internal-sl-triangle-1 (list 0 13tmlo 13tmhi (append unshared (butlast shared))))
	(setf new-internal-sl-triangle-2 (list 0 13tmlo 13tmhi (append unshared (last shared))))
	(setf new-internal-tl-triangle-1 (list 1 13tmlo 13tmhi (cons lopt unshared)))
	(setf new-internal-tl-triangle-2 (list 2 31tmlo 31tmhi (append unshared (cons hipt nil))))
	
	(unless (or (gethash new-internal-sl-triangle-1 *2SIMPLEX->ID*)
		    (gethash new-internal-sl-triangle-2 *2SIMPLEX->ID*)
		    (gethash new-internal-tl-triangle-1 *2SIMPLEX->ID*)
		    (gethash new-internal-tl-triangle-2 *2SIMPLEX->ID*))
	  (setf newsxdata (list (list 1 13tmlo 13tmhi (cons lopt (2sx-points new-internal-sl-triangle-1)))
				(list 1 13tmlo 13tmhi (cons lopt (2sx-points new-internal-sl-triangle-2)))
				(list 3 31tmlo 31tmhi (append (2sx-points new-internal-sl-triangle-1) 
							      (list hipt)))
				(list 3 31tmlo 31tmhi (append (2sx-points new-internal-sl-triangle-2) 
							      (list hipt)))))
	  (return-from try-4->4 (list newsxdata nbors curr old-internal-triangles DF44 DB44)))))))

(defun 2->3-subcomplex (sxid)
  "returns a list of the form ((1or3 13or31id 22id)...) where the first number 1 or 3 tells us about the
type of the simplex participating in the move"
  (let ((sx nil)
	(subcmplx nil))
    (when (setf sx (get-3simplex sxid))
      (cond ((or (= 1 (3sx-type sx)) (= 3 (3sx-type sx)))
	     (let ((22nbors (neighbors-of-type sx 2)))
	       (dolist (22nbor 22nbors)
		 (pushnew (list (3sx-type sx) sxid 22nbor) subcmplx :test #'set-equal?))))
	    ((= 2 (3sx-type sx))
	     (let ((13nbors (append (neighbors-of-type sx 1))))
	       (dolist (13nbor 13nbors)
		 (pushnew (list 1 13nbor sxid) subcmplx :test #'set-equal?)))
	     (let ((31nbors (append (neighbors-of-type sx 3))))
	       (dolist (31nbor 31nbors)
		 (pushnew (list 3 31nbor sxid) subcmplx :test #'set-equal?))))))
    subcmplx))

;; (1 | 2 3 4) (+) (1 5 | 3 4) --> (5 | 2 3 4) (+) (1 5 | 2 3) (+) (1 5 | 2 4)
(defun 2->3-move-internal-12 (13id 22id)
  "the 2,3 move performed on a (1,3) simplex attached to a (2,2) simplex"
  (let ((13sx nil) (22sx nil))
    (when (and (setf 13sx (get-3simplex 13id)) (setf 22sx (get-3simplex 22id)))
      (let* ((old2 (link-id 13id 22id))
	     (pts234 (3sx-hipts 13sx))    ;; hi points of the 1,3 simplex
	     (pts34 (3sx-hipts 22sx))  ;; hi points of the 2,2 simplex
	     (pts15 (3sx-lopts 22sx));; lo points of the 2,2 simplex
	     (pt5 (set-difference pts15 (3sx-lopts 13sx)))
	     (pt2 (set-difference pts234 pts34))
	     (new-internal-tlt-1 (list 1 (3sx-tmlo 13sx) (3sx-tmhi 13sx) 
				       (append pt5 pt2 (butlast pts34))))
	     (new-internal-tlt-2 (list 1 (3sx-tmlo 13sx) (3sx-tmhi 13sx)
				       (append pt5 pt2 (last pts34))))
	     (new-internal-tlt-3 (list 2 (3sx-tmlo 13sx) (3sx-tmhi 13sx) (append pts15 pt2)))
	     (new-13-pts (append pt5 pts234))
	     (new-22-pts-1 (append pts15 pt2 (butlast pts34)))
	     (new-22-pts-2 (append pts15 pt2 (last pts34)))
	     (nbors (set-difference (union (3sx-sx3ids 13sx) (3sx-sx3ids 22sx)) (list 0 13id 22id)))
	     (newsxdata nil))
	(unless (or (gethash new-internal-tlt-1 *2SIMPLEX->ID*)
		    (gethash new-internal-tlt-2 *2SIMPLEX->ID*)
		    (gethash new-internal-tlt-3 *2SIMPLEX->ID*))
	  (setf newsxdata (list (list 1 (3sx-tmlo 13sx) (3sx-tmhi 13sx) new-13-pts) 
				(list 2 (3sx-tmlo 22sx) (3sx-tmhi 22sx) new-22-pts-1) 
				(list 2 (3sx-tmlo 22sx) (3sx-tmhi 22sx) new-22-pts-2)))
	  (return-from 2->3-move-internal-12 (list newsxdata nbors (list 13id 22id) (list old2) DF23 (DB23 13id))))))))

;; (2 3 4 | 1) (+) (3 4 | 1 5) --> (2 3 4 | 5) (+) (2 3 | 1 5) (+) (2 4 | 1 5)
(defun 2->3-move-internal-32 (31id 22id)
  "the 2,3 move performed on a (3,1) simplex attached to a (2,2) simplex"
    (let ((31sx nil) (22sx nil))
    (when (and (setf 31sx (get-3simplex 31id)) (setf 22sx (get-3simplex 22id)))
      (let* ((old2 (link-id 31id 22id))
	     (pts234 (3sx-lopts 31sx))    ;; lo points of the 3,1 simplex
	     (pts34 (3sx-lopts 22sx))  ;; lo points of the 2,2 simplex
	     (pts15 (3sx-hipts 22sx));; hi points of the 2,2 simplex
	     (pt5 (set-difference pts15 (3sx-hipts 31sx)))
	     (pt2 (set-difference pts234 pts34))
	     (new-internal-tlt-1 (list 2 (3sx-tmlo 31sx) (3sx-tmhi 31sx) 
				       (append pt2 (butlast pts34) pt5)))
	     (new-internal-tlt-2 (list 2 (3sx-tmlo 31sx) (3sx-tmhi 31sx)
				       (append pt2 (last pts34) pt5)))
	     (new-internal-tlt-3 (list 1 (3sx-tmlo 31sx) (3sx-tmhi 31sx) (append pt2 pts15)))
	     (new-31-pts (append pts234 pt5))
	     (new-22-pts-1 (append pt2 (butlast pts34) pts15))
	     (new-22-pts-2 (append pt2 (last pts34) pts15))
	     (nbors (set-difference (union (3sx-sx3ids 31sx) (3sx-sx3ids 22sx)) (list 0 31id 22id)))
	     (newsxdata nil))

	(unless (or (gethash new-internal-tlt-1 *2SIMPLEX->ID*)
		    (gethash new-internal-tlt-2 *2SIMPLEX->ID*)
		    (gethash new-internal-tlt-3 *2SIMPLEX->ID*))
	  (setf newsxdata (list (list 3 (3sx-tmlo 31sx) (3sx-tmhi 31sx) new-31-pts) 
				(list 2 (3sx-tmlo 22sx) (3sx-tmhi 22sx) new-22-pts-1) 
				(list 2 (3sx-tmlo 22sx) (3sx-tmhi 22sx) new-22-pts-2)))
	  (return-from 2->3-move-internal-32 (list newsxdata nbors (list 31id 22id) (list old2) DF23 (DB23 31id))))))))

(defun try-2->3 (sxid)
  (let ((subcmplx (2->3-subcomplex sxid))
	(movedata nil))
    (unless (null subcmplx)
      (dolist (curr subcmplx)
	(cond ((= 1 (first curr))
	       (setf movedata (2->3-move-internal-12 (second curr) (third curr)))
	       (when movedata
		 (return-from try-2->3 movedata)))
	      ((= 3 (first curr))
	       (setf movedata (2->3-move-internal-32 (second curr) (third curr)))
	       (when movedata
		 (return-from try-2->3 movedata))))))))

(defun 3->2-subcomplex (sxid)
  "returns a list of the form ((1or3 13or31id 22id1 22id2)...) where the first number 1 or 3 tells us 
about the type of the simplex participating in the move"
  (let ((sx nil)
	(subcmplx nil))
    (when (setf sx (get-3simplex sxid))
      (cond ((or (= 1 (3sx-type sx)) (= 3 (3sx-type sx)))
	     (let ((22nbors (neighbors-of-type sx 2)))
	       (dolist (22nbor 22nbors)
		 (let ((22sx (get-3simplex 22nbor)))
		   (when 22sx
		     (let ((22nborsof22nbor (neighbors-of-type 22sx 2)))
		       (dolist (22nborof22nbor 22nborsof22nbor)
			 (when (3simplices-connected? 22nborof22nbor sxid)
			   (pushnew (list (3sx-type sx) sxid 22nbor 22nborof22nbor) subcmplx 
				    :test #'set-equal?)))))))))
	    ((= 2 (3sx-type sx))
	     (let ((22nbors (neighbors-of-type sx 2)))
	       (dolist (22nbor 22nbors)
		 (let ((22sx (get-3simplex 22nbor)))
		   (when 22sx
		     (let ((13nborsof22nbor (neighbors-of-type 22sx 1)))
		       (dolist (13nborof22nbor 13nborsof22nbor)
			 (when (3simplices-connected? 13nborof22nbor sxid)
			   (pushnew (list 1 13nborof22nbor sxid 22nbor) subcmplx :test #'set-equal?))))
		     (let ((31nborsof22nbor (neighbors-of-type 22sx 3)))
		       (dolist (31nborof22nbor 31nborsof22nbor)
			 (when (3simplices-connected? 31nborof22nbor sxid)
			   (pushnew (list 3 31nborof22nbor sxid 22nbor) subcmplx :test #'set-equal?)))))))))))
    subcmplx))
;; (5 | 2 3 4) (+) (1 5 | 2 3) (+) (1 5 | 2 4) --> (1 | 2 3 4) (+) (1 5 | 3 4)
(defun 3->2-move-internal-122 (13id 22id1 22id2)
  "the (3,2) move performed on a (1,3) simplex attached to two (2,2) simplices"
  (let ((13sx nil) (22sx1 nil) (22sx2 nil))
    (when (and (setf 13sx (get-3simplex 13id)) 
	       (setf 22sx1 (get-3simplex 22id1))
	       (setf 22sx2 (get-3simplex 22id2)))
      (let* ((old2s (list (link-id 13id 22id1) (link-id 13id 22id2) (link-id 22id1 22id2)))
	     (pts234 (3sx-hipts 13sx))
	     (pts15 (3sx-lopts 22sx1))
	     (pt1 (set-difference pts15 (3sx-lopts 13sx)))
	     (pts34 (set-exclusive-or (3sx-hipts 22sx1) (3sx-hipts 22sx2)))
	     (new-internal-triangle (list 1 (3sx-tmlo 13sx) (3sx-tmhi 13sx) (append pt1 pts34)))
	     (new-13-pts (append pt1 pts234))
	     (new-22-pts (append pts15 pts34))
	     (nbors (set-difference (unions (3sx-sx3ids 13sx) (3sx-sx3ids 22sx1) (3sx-sx3ids 22sx2)) 
				    (list 0 13id 22id1 22id2)))
	     (newsxdata nil))
	(unless (gethash new-internal-triangle *2SIMPLEX->ID*)
	  (setf newsxdata (list (list 1 (3sx-tmlo 13sx) (3sx-tmhi 13sx) new-13-pts) 
				(list 2 (3sx-tmlo 22sx1) (3sx-tmhi 22sx2) new-22-pts)))
	  (return-from 3->2-move-internal-122 (list newsxdata nbors (list 13id 22id1 22id2) old2s DF32 (DB32 13id))))))))
	
(defun 3->2-move-internal-322 (31id 22id1 22id2)
  "the (3,2) move performed on a (3,1) simplex attached to two (2,2) simplices"
  (let ((31sx nil) (22sx1 nil) (22sx2 nil))
    (when (and (setf 31sx (get-3simplex 31id)) 
	       (setf 22sx1 (get-3simplex 22id1))
	       (setf 22sx2 (get-3simplex 22id2)))
      (let* ((old2s (list (link-id 31id 22id1) (link-id 31id 22id2) (link-id 22id1 22id2)))
	     (pts234 (3sx-lopts 31sx)) ;; lo points of 3,1
	     (pts15 (3sx-hipts 22sx1))   ;; hi points of 2,2
	     (pt1 (set-difference pts15 (3sx-hipts 31sx))) ;; 2,2 hi - 3,1 hi
	     (pts34 (set-exclusive-or (3sx-lopts 22sx1) (3sx-lopts 22sx2)))
	     (new-internal-triangle (list 2 (3sx-tmlo 31sx) (3sx-tmhi 31sx) (append pts34 pt1)))
	     (new-31-pts (append pts234 pt1))
	     (new-22-pts (append pts34 pts15))
	     (nbors (set-difference (unions (3sx-sx3ids 31sx) (3sx-sx3ids 22sx1) (3sx-sx3ids 22sx2)) 
				    (list 0 31id 22id1 22id2)))
	     (newsxdata nil))
	(unless (gethash new-internal-triangle *2SIMPLEX->ID*)
	  (setf newsxdata (list (list 3 (3sx-tmlo 31sx) (3sx-tmhi 31sx) new-31-pts) 
				(list 2 (3sx-tmlo 22sx1) (3sx-tmhi 22sx2) new-22-pts))) 
	  (return-from 3->2-move-internal-322 (list newsxdata nbors (list 31id 22id1 22id2) old2s DF32 (DB32 31id))))))))

(defun try-3->2 (sxid)
  (let ((subcmplx (3->2-subcomplex sxid))
	(movedata nil))
    (unless (null subcmplx)
      (dolist (curr subcmplx)
	(cond ((= 1 (first curr))
	       (setf movedata (3->2-move-internal-122 (second curr) (third curr) (fourth curr)))
	       (when movedata
		 (return-from try-3->2 movedata)))
	      ((= 3 (first curr))
	       (setf movedata (3->2-move-internal-322 (second curr) (third curr) (fourth curr)))
	       (when movedata 
		 (return-from try-3->2 movedata))))))))
;...........................................................................................................
; cdt-2plus1-initialization.lisp
;...........................................................................................................

;;function to find neighbors of a given triangle in a list of triangles (triangles are stored as
;;3-tuples of vertices)
(defun get-nbors-of-triangle (key-triangle list-of-triangles)
  (let ((retval ()))
    (dolist (tri list-of-triangles)
      (when (= 2 (length (intersection tri key-triangle)))
	(setf retval (push tri retval))))
    retval))

;;find all triangles containing a particular point.  triangles are represented in a list of 3-tuples
(defun triangles-around-point (point list-of-triangles)
  (let ((retval ()))
    (dolist (tri list-of-triangles)
      (when (intersection tri (list point))
	(setf retval (push tri retval))))
    retval))

;;function to retrieve "pseudo-faces" and "pseudo-edges" from a list of triangle verticies,
;; of the form ((id1 id2 id3) ...).

;;the return value is of the form 

;;  ((point1 point2 point3 point4) (face1 face2 face3 face4) (edge12 edge13 edge14 edge23 edge24 edge34))

;;where faces are lists of 3-tuples of vertices and edges are lists of pairs of vertices.  the numbers
;;in the edge names refer to the numbers of the end points.  the numbers of points are the same
;;as the numbers of the faces opposite the points.  point* are just the point ids of the points that
;;are the verticies of the "tetrahedra" that we are pretending the s2 triangulation is.  

(defun get-s2-pseudo-faces-and-edges (triangle-sheet)

  ;;TODO come up with a more even way of splitting the sheet into faces

  (let* (;;pick a random triangle for face1
	 (face1 (list (nth (random (length triangle-sheet)) triangle-sheet)))
	 
	 ;;choose a random neighbor of that triangle to be face2.  the vertex of face2 not shared
	 ;;with face1 becomes point1.  the vertex of face1 not shared with face2 becomes point2
	 (face2  (list (first (get-nbors-of-triangle (first face1) triangle-sheet))))
	 (point1 (first (set-difference (first face2) (first face1))))
	 (point2 (first (set-difference (first face1) (first face2))))
		 
	 ;;choose all other triangles meeting at a random endpoint of the border line segment for face3.
	 ;;the endpoint selected becomes point4, the other endpoint becomes point3.  the edge along the rounded part
	 ;;of this "triangle fan" is the only non-trivial edge (edge12) to construct.  
	 (border-segment (intersection (first face1) (first face2)))
	 (point3 (first  border-segment))
	 (point4 (second border-segment))
	 (face3 (set-difference
		 (triangles-around-point point4 triangle-sheet)
		 (concatenate 'list face1 face2)
		 :test #'(lambda (x y) (not (set-difference x y))))) ;(assuming x and y have the same cardinality)
	 (edge12 (map 'list #'(lambda (x) (set-difference x (list point4))) face3))

	 ;;come up with other edges
	 (edge13 (list (list point1 point3)))
	 (edge14 (list (list point1 point4)))
	 (edge23 (list (list point2 point3)))
	 (edge24 (list (list point2 point4)))
	 (edge34 (list (list point3 point4)))
	 
	 ;;all other triangles form face4
	 (face4 (set-difference triangle-sheet 
				(concatenate 'list face1 face2 face3) 
				:test #'(lambda (x y) (not (set-difference x y))))))

    ;;get all of the values into a list to return
    (list (list point1 point2 point3 point4)
	  (list face1  face2  face3  face4 )
	  (list edge12 edge13 edge14 edge23 edge24 edge34))))

;;an analogous function to get-s2-pseudo-faces-and-edges, but for triangle-sheet of t2 topology
(defun get-t2-pseudo-faces-and-edges (triangle-sheet)
  (declare (ignore triangle-sheet))
  (error "t2 topology not implemented yet"))

;;functions/macros to triangulate different types of complices into many simplices of the same type.  the 
;;simplices are returned as a list of lists, each with the form (type tmlo tmhi id1 id2 id3 id4), for
;;easy use with make-simplex-v3.  

(defun triangulate-31-complex (face point tmlo tmhi)
  (if (> tmlo tmhi) 
      (triangulate-13-complex point face tmhi tmlo) ;this causes warnings, but is harmless
      (map 'list #'(lambda (x) (list 3 tmlo tmhi (first x) (second x) (third x) point)) face)))

(defun triangulate-13-complex (point face tmlo tmhi)
  (if (> tmlo tmhi)
      (triangulate-31-complex face point tmhi tmlo)
      (map 'list #'(lambda (x) (list 1 tmlo tmhi point (first x) (second x) (third x))) face)))

(defun triangulate-22-complex (edge1 edge2 tmlo tmhi)
  (if (> tmlo tmhi)
      (triangulate-22-complex edge2 edge1 tmhi tmlo)
      (let ((retval ()))
	(dolist (lo-edge edge1)
	  (dolist (hi-edge edge2)
	    (push (list 2 tmlo tmhi (first lo-edge) (second lo-edge) (first hi-edge) (second hi-edge))
		  retval)))
	retval)))

;;original-sheet and new-sheet are lists of 3-tuples of pt ids, to be connected by tetrahedra.  
;;the function will return a list of tetrahedra connecting the two sheets of triangles, such that 
;;all tetrahedra meet at time-like faces with one another.  both sheets are assumed to have topology s2.

;;the list of returned tetrahedra is of the form
;;((type tmlo tmhi id1 id2 id3 id4) ... ),
;;for use with make-simplex-v3.  the call to make-simplex will automatically update the last-used
;;point id as tethrahedra are added to the hash table.

;;point ids in original-sheet will not be changed.  values in new-sheet will be set to 
;;reflect connectivity with original-sheet.  t0 will become the new time value of all verticies in
;;original-sheet and t1 will be the new time value for verticies in new-sheet.  last-used-pt-id is the 
;;last used id of points and will be added to all id's in new-sheet to prevent spurious connections to 
;;other geometry

(defun triangulate-between-s2-slices (original-sheet new-sheet t0 t1 last-used-pt-id)

  ;;the approach here is to break each s2-topology sheet of triangles into four "pseudo-faces",
  ;;connected analogously to those of a single tetrahedron.  we can then follow the program
  ;;for filling the space between two tetrahedra, with the slight complication that the 3-simplices
  ;;of the inter-tetrahedral filling are replaced with analogous complices, each of which may be
  ;;decomposed into many simplices of the same type.  

  ;;add last-used-pt-id to all verticies of new-sheet
  (let* ((adjusted-new-sheet (map 'list #'(lambda (x) (map 'list #'(lambda (y) (+ y last-used-pt-id)) x)) new-sheet))
	 
	 ;;first, we must decide on the pseudo-faces and pseudo-edges.  Store the pseudo-faces as lists of 
	 ;;triangles, and pseudo-edges as lists of pairs of points.

	 ;;get the points, faces, and edges
	 (original-pseudo-faces-and-edges (get-s2-pseudo-faces-and-edges original-sheet))
	 (new-pseudo-faces-and-edges      (get-s2-pseudo-faces-and-edges adjusted-new-sheet))

	 ;;make convenient bindings for the points, faces and edges
	 (original-points (first  original-pseudo-faces-and-edges))
	 (original-faces  (second original-pseudo-faces-and-edges))
	 (original-edges  (third  original-pseudo-faces-and-edges))
	 (new-points      (first  new-pseudo-faces-and-edges))
	 (new-faces       (second new-pseudo-faces-and-edges))
	 (new-edges       (third  new-pseudo-faces-and-edges))

	 ;;come up with numbered names for easier correspondence with the inter-tetrahedral
	 ;;filling scheme (vertex numbers opposite face numbers)

	 ;;verticies
	 (point1 (first  original-points))
	 (point2 (second original-points))
	 (point3 (third  original-points))
	 (point4 (fourth original-points))
	 (point5 (first  new-points))
	 (point6 (second new-points))
	 (point7 (third  new-points))
	 (point8 (fourth new-points))

	 ;;faces
	 (face1 (first  original-faces))
	 (face2 (second original-faces))
	 (face3 (third  original-faces))
	 (face4 (fourth original-faces))
	 (face5 (first  new-faces))
	 (face6 (second new-faces))
	 (face7 (third  new-faces))
	 (face8 (fourth new-faces))
	 
	 ;;name edges in terms of which points they connect
	 (edge12 (first  original-edges))
	 (edge13 (second original-edges))
	 (edge14 (third  original-edges))
	 (edge23 (fourth original-edges))
	 (edge24 (fifth  original-edges))
	 (edge34 (sixth  original-edges))
	 (edge56 (first  new-edges))
	 (edge57 (second new-edges))
	 (edge58 (third  new-edges))
	 (edge67 (fourth new-edges))
	 (edge68 (fifth  new-edges))
	 (edge78 (sixth  new-edges)))

    ;;use the point/face/edge bindings and the triangulation between tetrahedra scheme
    ;;to come up with the complices that correctly triangulate between the two sheets
    (concatenate 'list

		 ;;(3,1) complices:
		 (triangulate-31-complex face4 point5 t0 t1)
		 (triangulate-31-complex face1 point6 t0 t1)
		 (triangulate-31-complex face2 point7 t0 t1)
		 (triangulate-31-complex face3 point8 t0 t1)

		 ;;(2,2) complices:
		 (triangulate-22-complex edge12 edge58 t0 t1)
		 (triangulate-22-complex edge23 edge56 t0 t1)
		 (triangulate-22-complex edge13 edge57 t0 t1)
		 (triangulate-22-complex edge34 edge67 t0 t1)
		 (triangulate-22-complex edge24 edge68 t0 t1)
		 (triangulate-22-complex edge14 edge78 t0 t1)

		 ;;(1,3) complices:
		 (triangulate-13-complex point1 face6 t0 t1)
		 (triangulate-13-complex point2 face7 t0 t1)
		 (triangulate-13-complex point3 face8 t0 t1)
		 (triangulate-13-complex point4 face5 t0 t1))))

;;anaologous function for triangle sheets of t2 topology
(defun triangulate-between-t2-slices (original-sheet new-sheet t0 t1 last-used-pt-id)
  (declare (ignore original-sheet)
	   (ignore new-sheet)
	   (ignore t0)
	   (ignore t1)
	   (ignore last-used-pt-id))
  (error "t2 topology not yet implemented"))

;;macro to automatically choose the right triangulation between slices
(defmacro triangulate-between-slices (original-sheet new-sheet t0 t1 last-used-pt-id)
  `(cond 
     ((string= STOPOLOGY "S2")
      (triangulate-between-s2-slices ,original-sheet ,new-sheet ,t0 ,t1 ,last-used-pt-id))
     ((string= STOPOLOGY "T2")
      (triangulate-between-t2-slices ,original-sheet ,new-sheet ,t0 ,t1 ,last-used-pt-id))
     (t (error "unrecognized spatial topology"))))

;;test function to generate an s2 triangulation of arbitrary size.  this particular method focuses
;;a lot of curvature at a few points, so it's not particularly spherical, but it is a useful test
;;when only topology matters
(defun generate-s2-triangulation-of-size (n)
  
  (let* ((triangulation (list (list 4 3 2) (list 1 3 4) (list 1 4 2) (list 2 3 1)))
	 (number-of-triangles 4)
	 (current-triangle () )
	 (rest-of-list     () )
	 (last-used-point 4))
    (while (< number-of-triangles n)
      (setf current-triangle triangulation)
      (while (and (< number-of-triangles n) (setf rest-of-list (cdr current-triangle)))
	(let* ((triangle (car current-triangle))
	       (p1 (first triangle)) (p2 (second triangle)) (p3 (third triangle))
	       (p4 (incf last-used-point)))
	  (setf (car current-triangle) (list p1 p4 p3))
	  (setf (cdr current-triangle) (concatenate 'list (list (list p1 p2 p4) (list p2 p3 p4)) rest-of-list))
	  (setf current-triangle (cdr (cdr (cdr current-triangle))))
	  (setf number-of-triangles (+ 2 number-of-triangles)))))
    triangulation))

;;function to load a set of triangles from a file.  the triangles are assumed to be stored as a
;;lisp readable list of lists of 3 integers each.  The 3 integers represent point ids.  The point id's
;;can just start at 1, as they will be fixed to match the rest of the spacetime later.  
(defun load-triangles-from-file (filename)
  (with-open-file (f filename)
    (read f)))

;;function to connect simplices that have been generated
;;by initialization functions
(defun connect-existing-simplices (&optional initial-spatial-geometry final-spatial-geometry)
  
  (cond
    ((string= BCTYPE "PERIODIC")

     ;;the code in "simplex.lisp" will automatically modulo high time-stamps
     ;; by NUM-T, wrapping the geometry around at the end
     (for (ts 0 (- NUM-T 1))
	  (connect-simplices-in-sandwich ts (1+ ts) )
	  (connect-simplices-in-adjacent-sandwiches ts (+ ts 1) (+ ts 2)))

     ;;periodicity gives a 1-to-1 correspondence between spatial
     ;;sheets and 3-d sandwiches, so all per-slice quantities are
     ;;just multiplied by NUM-T
     (set-f-vector (* NUM-T N0-PER-SLICE)                               ; N0
		   (* NUM-T N1-SL-PER-SLICE)                            ; N1-SL
		   (* NUM-T N1-TL-PER-SLICE)                            ; N1-TL
		   (* NUM-T N2-SL-PER-SLICE)                            ; N2-SL
		   (* NUM-T N2-TL-PER-SLICE)                            ; N2-TL
		   (* NUM-T (+ N3-TL-13-PER-SLICE N3-TL-31-PER-SLICE))  ; N3-TL-13 + N3-TL-31
		   (* NUM-T N3-TL-22-PER-SLICE)))                       ; N3-TL-22

    ((string= BCTYPE "OPEN")

     ;;set the geometries of the initial and final slices according to the optional file parameters,
     ;;defaulting to single tetrahedra when no filenames are given

     (when initial-spatial-geometry
       (let ((existing-triangles ()))
	 (dolist (3sxid (get-simplices-in-sandwich 0 1))
	   (let* ((3sx  (get-3simplex 3sxid))
		  (pts (3sx-points 3sx)))
	     (when (= 1 (3sx-type 3sx))
	       (push (list (second pts) (third pts) (fourth pts)) existing-triangles)))
	   (remhash 3sxid *ID->3SIMPLEX*))
	 (map 'list 
	      #'(lambda (x) (make-3simplex-v3 (first x) (second x) (third x) (fourth x) (fifth x) (sixth x) (seventh x)))
	      (triangulate-between-slices existing-triangles 
					     (load-triangles-from-file initial-spatial-geometry)
					     1 0 *LAST-USED-POINT*))))
     (when final-spatial-geometry
       (let ((existing-triangles ()))
	 (dolist (3sxid (get-simplices-in-sandwich (1- NUM-T) NUM-T))
	   (let* ((3sx  (get-3simplex 3sxid))
		  (pts (3sx-points 3sx)))
	     (when (= 3 (3sx-type 3sx))
	       (push (list (first pts) (second pts) (third pts)) existing-triangles)))
	   (remhash 3sxid *ID->3SIMPLEX*))
	 (map 'list 
	      #'(lambda (x) (make-3simplex-v3 (first x) (second x) (third x) (fourth x) (fifth x) (sixth x) (seventh x)))
	      (triangulate-between-slices existing-triangles 
					     (load-triangles-from-file final-spatial-geometry)
					     (1- NUM-T) NUM-T *LAST-USED-POINT*))))

     ;;connect simplices inside of slices
     (for (ts 0  (1- NUM-T))
        (connect-simplices-in-sandwich ts (1+ ts))
        (connect-simplices-in-adjacent-sandwiches ts (+ ts 1) (+ ts 2)))

     ;;set the f-vector.  make sure to consider the arbitrary boundary sheets
     ;;of triangles, computing and adding their contributions separately
     (set-f-vector 
      
      ;; N0
      (+ (count-points-at-time 0)
	 (count-points-at-time NUM-T)
	 (* (1- NUM-T) N0-PER-SLICE))

      ;;N1-SL
      (+ (count-spacelike-links-at-time 0)
	 (count-spacelike-links-at-time NUM-T)
	 (* (1- NUM-T) N1-SL-PER-SLICE)) 
      
      ;;N1-TL
      (+ (count-timelike-links-in-sandwich 0 1)
	 (count-timelike-links-in-sandwich (1- NUM-T) NUM-T)
	 (* (- NUM-T 2) N1-TL-PER-SLICE))
      
      ;;N2-SL
      (+ (count-spacelike-triangles-at-time 0)
	 (count-spacelike-triangles-at-time NUM-T)
	 (* (1- NUM-T) N2-SL-PER-SLICE)) 
      
      ;;N2-TL
      (+ (count-timelike-triangles-in-sandwich 0 1)
	 (count-timelike-triangles-in-sandwich (1- NUM-T) NUM-T)
	 (* (- NUM-T 2) N2-TL-PER-SLICE))
      
      ;;N3 = N3-TL-13 + N3-TL-31
      (+ (count-simplices-of-type 3)
	 (count-simplices-of-type 1))
      
      ;;N3-TL-22
      (count-simplices-of-type 2))

     ;;set the initial values of the b-vector (numbers of things on a boundary)
     (set-b-vector (+ (count-points-at-time 0) (count-points-at-time NUM-T))
		   (+ (count-simplices-in-sandwich-of-type 0 1 2)
		      (count-simplices-in-sandwich-of-type (1- NUM-T) NUM-T 2))
		   (+ (count-simplices-in-sandwich-of-type 0 1 3)
		      (count-simplices-in-sandwich-of-type (1- NUM-T) NUM-T 1))))

    (t (error "unrecognized boundary condition type"))))


(defun initialize-S2-triangulation (num-time-slices boundary-conditions 
				    &optional 
				    initial-spatial-geometry
				    final-spatial-geometry)

  (setf NUM-T   num-time-slices
        BCTYPE  (string-upcase boundary-conditions))

  ;;set up the numbers of initial simplices according to the S2
  ;;initialization of the geometry
  (defparameter N0-PER-SLICE 4)
  (defparameter N1-SL-PER-SLICE 6)
  (defparameter N1-TL-PER-SLICE 12)
  (defparameter N2-SL-PER-SLICE 4)
  (defparameter N2-TL-PER-SLICE 24)
  (defparameter N3-TL-13-PER-SLICE 4)
  (defparameter N3-TL-22-PER-SLICE 6)
  (defparameter N3-TL-31-PER-SLICE 4) ; here (3,1) means just (3,1), not (3,1)+(1,3)                 
  (defparameter S2-1/2-31 '((1 2 3 5) (2 3 4 6) (3 4 1 7) (4 1 2 8)))
  (defparameter S2-1/2-22 '((1 2 5 8) (2 3 5 6) (3 1 5 7) (3 4 6 7) (4 2 6 8) (4 1 7 8)))
  (defparameter S2-1/2-13 '((1 5 7 8) (2 5 6 8) (3 5 6 7) (4 6 7 8)))

  (for (n 0 (1- (/ NUM-T 2)))
       (dolist (fourpts S2-1/2-31)
	 (make-3simplex-v3 3 (* 2 n) (1+ (* 2 n))                       ;-----o------------ t = 1
			   (+ (* 2 n N0-PER-SLICE) (first fourpts))     ;    / \
			   (+ (* 2 n N0-PER-SLICE) (second fourpts))    ;   /   \
			   (+ (* 2 n N0-PER-SLICE) (third fourpts))     ;  /     \
			   (+ (* 2 n N0-PER-SLICE) (fourth fourpts))))  ;-o-------o-------- t = 0
       (dolist (fourpts S2-1/2-22)
	 (make-3simplex-v3 2 (* 2 n) (1+ (* 2 n))                       ;-----o-----o------ t = 1
			   (+ (* 2 n N0-PER-SLICE) (first fourpts))     ;    /     / 
			   (+ (* 2 n N0-PER-SLICE) (second fourpts))    ;   /     /     
			   (+ (* 2 n N0-PER-SLICE) (third fourpts))     ;  /     /  
			   (+ (* 2 n N0-PER-SLICE) (fourth fourpts))))  ;-o-----o---------- t = 0
       (dolist (fourpts S2-1/2-13)
	 (make-3simplex-v3 1 (* 2 n) (1+ (* 2 n))                       ;-o-------o-------- t = 1
			   (+ (* 2 n N0-PER-SLICE) (first fourpts))     ;  \     /
			   (+ (* 2 n N0-PER-SLICE) (second fourpts))    ;   \   /
			   (+ (* 2 n N0-PER-SLICE) (third fourpts))     ;    \ /
			   (+ (* 2 n N0-PER-SLICE) (fourth fourpts))))  ;-----o------------ t = 0
       (dolist (fourpts S2-1/2-31)
	 (make-3simplex-v3 1 (1+ (* 2 n)) (2+ (* 2 n))                      ;-o-------o-------- t = 2
			   (+ (* 2 n N0-PER-SLICE) (fourth fourpts))        ;  \     /
			   (+ (* 2 (+ n 1) N0-PER-SLICE) (first fourpts))   ;   \   /
			   (+ (* 2 (+ n 1) N0-PER-SLICE) (second fourpts))  ;    \ /
			   (+ (* 2 (+ n 1) N0-PER-SLICE) (third fourpts)))) ;-----o------------ t = 1
       (dolist (fourpts S2-1/2-22)
	 (make-3simplex-v3 2 (1+ (* 2 n)) (2+ (* 2 n))                      ;-----o-----o------ t = 2
			   (+ (* 2 n N0-PER-SLICE) (third fourpts))         ;      \     \  
			   (+ (* 2 n N0-PER-SLICE) (fourth fourpts))        ;       \     \
			   (+ (* 2 (+ n 1) N0-PER-SLICE) (first fourpts))   ;        \     \
			   (+ (* 2 (+ n 1) N0-PER-SLICE) (second fourpts))));---------o-----o-- t = 1
       (dolist (fourpts S2-1/2-13)
	 (make-3simplex-v3 3 (1+ (* 2 n)) (2+ (* 2 n))                      ;-----o------------ t = 2
			   (+ (* 2 n N0-PER-SLICE) (second fourpts))        ;    / \
			   (+ (* 2 n N0-PER-SLICE) (third fourpts))         ;   /   \
			   (+ (* 2 n N0-PER-SLICE) (fourth fourpts))        ;  /     \
			   (+ (* 2 (+ n 1) N0-PER-SLICE) (first fourpts)))));-o-------o-------- t = 1

  ;;match triangular faces between 3-simplices
  (connect-existing-simplices initial-spatial-geometry final-spatial-geometry))

(defun initialize-T2-triangulation (num-time-slices boundary-conditions
				    &optional 
				    initial-spatial-geometry
				    final-spatial-geometry)

  (setf NUM-T   num-time-slices
        BCTYPE  (string-upcase boundary-conditions))

  ;;this code assumes that each toroidal space is being triangulated
  ;;with 32 triangles.  this is not minimal, but it allows for a
  ;;simpler initialization.
  ;;
  ;;  the first torus is triangulated as below
  ;;
  ;;   1   5  9  13   1
  ;;    o--o--o--o--o
  ;;    | /| /| /| /|        each subsequent 
  ;;    |/ |/ |/ |/ |        torus has its 
  ;; 2  o--o--o--o--o 2      points indexed
  ;;    | /| /| /| /|        16 higher than
  ;;    |/ |/ |/ |/ |        the previous
  ;; 3  o--o--o--o--o 3      torus
  ;;    | /| /| /| /|
  ;;    |/ |/ |/ |/ |        
  ;; 4  o--o--o--o--o 4      the TL simplicial filling
  ;;    | /| /| /| /|        alternates between cells
  ;;    |/ |/ |/ |/ |        in a checker-board pattern
  ;;    o--o--o--o--o        so that TL links never cross
  ;;   1   5  9  13   1
  ;;

  ;;set up the numbers of initial simplices according to the T2
  ;;initialization of the geometry
  (defparameter N0-PER-SLICE 16)        ; count one corner of each cell
  (defparameter N1-SL-PER-SLICE 48)     ; (3 per cell) x (16 cells)
  (defparameter N1-TL-PER-SLICE 48)     ; (1 internal + 2 external per cell) x (16 cells)
  (defparameter N2-SL-PER-SLICE 32)     ; (2 per cell) x (16 cells)
  (defparameter N2-TL-PER-SLICE 96)     ; (2 internal + 4 external per cell) x (16 cells)
  (defparameter N3-TL-13-PER-SLICE 32)  ; <---|
  (defparameter N3-TL-22-PER-SLICE 32)  ; <---|---| two of each type per cell
  (defparameter N3-TL-31-PER-SLICE 32)  ; <---|

  ;;iterate over time slices
  (for (time-slice 0 (1- NUM-T))

    ;;for each time slice, iterate over rows and columns
    ;;of the flattened torus rectangle
    (for (n 0 3) (for (m 0 3)

      (let* (;;define point id's for current time slice
             (p0 (+ 1 (* 16 time-slice) m (* 4 n)))
             (p1 (+ 1 (* 16 time-slice) m (* 4 (mod (1+ n) 4))))
             (p2 (+ 1 (* 16 time-slice) (mod (1+ m) 4) (* 4 n)))
             (p3 (+ 1 (* 16 time-slice) (mod (1+ m) 4) (* 4 (mod (1+ n) 4))))
             ;;define corresponding point id's for next time slice
             (p0-next (+ 16 p0))
             (p1-next (+ 16 p1))
             (p2-next (+ 16 p2))
             (p3-next (+ 16 p3)))

         ;;create simplices for current cell of flattened torus

         ;;enforce checkerboard pattern to prevent crossing of TL links
         (if (evenp (+ n m))

           (progn ;;create 6 3-simplices for the current cell

             (make-3simplex-v3 3 time-slice (1+ time-slice) p0  p1      p2      p1-next)
             (make-3simplex-v3 2 time-slice (1+ time-slice) p0  p2      p1-next p2-next)
             (make-3simplex-v3 1 time-slice (1+ time-slice) p0  p0-next p1-next p2-next)

             (make-3simplex-v3 3 time-slice (1+ time-slice) p1  p2      p3      p1-next)
             (make-3simplex-v3 2 time-slice (1+ time-slice) p2  p3      p1-next p2-next)
             (make-3simplex-v3 1 time-slice (1+ time-slice) p3  p1-next p2-next p3-next))

           (progn ;;otherwise, invert the simplicial breakdown (along the time-direction)

             (make-3simplex-v3 1 time-slice (1+ time-slice) p1  p0-next p1-next p2-next)
             (make-3simplex-v3 2 time-slice (1+ time-slice) p1  p2      p0-next p2-next)
             (make-3simplex-v3 3 time-slice (1+ time-slice) p0  p1      p2      p0-next)

             (make-3simplex-v3 1 time-slice (1+ time-slice) p1  p1-next p2-next p3-next)
             (make-3simplex-v3 2 time-slice (1+ time-slice) p1  p2      p2-next p3-next)
             (make-3simplex-v3 3 time-slice (1+ time-slice) p1  p2      p3      p3-next)))))))

  ;;match triangular faces between 3-simplices
  (connect-existing-simplices initial-spatial-geometry final-spatial-geometry))
            


(defun initialize-T-slices-with-V-volume (&key 
					  num-time-slices
					  target-volume
					  spatial-topology
					  boundary-conditions
					  initial-spatial-geometry
					  final-spatial-geometry)

  ;;set global variables according to parameters
  (setf STOPOLOGY  (string-upcase spatial-topology))

  ;;perform initialization based on type of spatial topology
  (cond 
    ((string= STOPOLOGY "S2") (initialize-S2-triangulation num-time-slices boundary-conditions 
							   initial-spatial-geometry
							   final-spatial-geometry))
    ((string= STOPOLOGY "T2") (initialize-T2-triangulation num-time-slices boundary-conditions
							   initial-spatial-geometry
							   final-spatial-geometry))
    (t                        (error "unrecognized spatial topology")))
  
  (format t "initial count = ~A~%" (count-simplices-of-all-types))

  ;;try volume-increasing moves on random simplices until the desired volume is reached
  (while (< (N3) target-volume)
    (let* ((type-chooser (random 6)) ;the range of type-chooser affects 23 / 13 / 31 balance
	   (movedata (try-move (random *LAST-USED-3SXID*) (if (< type-chooser 1) 0 1))))
      (when movedata (2plus1move movedata))))

  ;; ;;use moves to increase the number of simplices until the target
  ;; ;;volume is reached  
  ;; (loop named tv
  ;;    do

  ;;      (dolist (id23 (get-simplices-of-type 2))
  ;; 	 (let ((movedata nil))
  ;; 	   (when (setf movedata (try-2->3 id23))
  ;; 	     (2plus1move movedata)))
  ;; 	 (if (> (N3) target-volume)
  ;; 	     (return-from tv)))

  ;;      (dolist (id26 (get-simplices-of-type 1))
  ;; 	 (let ((movedata nil))
  ;; 	   (when (setf movedata (try-2->6 id26))
  ;; 	     (2plus1move movedata)))
  ;; 	 (if (> (N3) target-volume)
  ;; 	     (return-from tv)))

  ;;      (dolist (id23 (get-simplices-of-type 2))
  ;; 	 (let ((movedata nil))
  ;; 	   (when (setf movedata (try-2->3 id23))
  ;; 	     (2plus1move movedata)))
  ;; 	 (if (> (N3) target-volume)
  ;; 	     (return-from tv))))


  (format t "final count = ~A~%" (count-simplices-of-all-types))

  (format t "breakdown by location = ~a~%" (count-boundary-vs-bulk))

  (setf N-INIT (N3)))
; cdt-2plus1-montecarlo.lisp

;; translate a move type into an actual move
(defun try-move (sxid mtype)
  (let ((sx (get-3simplex sxid)))
    (if (and sx (is-real-simplex sx))
	(ecase mtype
	  (0 (try-2->6 sxid))
	  (1 (try-2->3 sxid))
	  (2 (try-4->4 sxid))
	  (3 (try-3->2 sxid))
	  (4 (try-6->2 sxid)))
	nil)))

(defun random-move (nsweeps)
  (loop :for sweepnum :from 1 :to nsweeps
     do
     (let* ((id (random *LAST-USED-3SXID*))
	    (mtype (select-move))
	    (sx (get-3simplex id))
	    (movedata nil))

       (incf CURRENT-MOVE-NUMBER)
       (when (and sx (setf movedata (try-move id mtype)))
	 (2plus1move movedata))
       (when (= 0 (mod sweepnum 1000))
	 (format t "finished ~A of ~A sweeps with count ~A~%" sweepnum nsweeps 
		 (count-simplices-of-all-types))
	 (finish-output)))))

(defun accept-move? (mtype sxid)

  (let* (;;determine what change vectors to use, based on the type of move
	
	 ;;this is the change in the f-vector due to the move (see the DF*
	 ;;parameters and/or macros in "globals.lisp")
	 (DF
	  (ecase mtype
	    (0;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 2->6
	     (DF26 sxid))
	    (1;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 2->3
	     DF23)
	    (2;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 4->4
	     DF44)
	    (3;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 3->2
	     DF32)
	    (4;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 6->2
	     (DF62 sxid))))
	 
	 ;;this is the change in some relevant quantities at the boundary
	 ;;(see the macros/paramters DB* in "globals.lisp")
	 (DB
	  (ecase mtype
	    (0;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 2->6
	     (DB26 sxid))
	    (1;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 2->3
	     (DB23 sxid))
	    (2;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 4->4
	     DB44)
	    (3;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 3->2
	     (DB32 sxid))
	    (4;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 6->2
	     (DB62 sxid))))
		 
	 ;;determine changes in different numbers of geometrical objects
	 (d-n3       (+ (seventh DF) (sixth DF)))
	 (d-n1-sl    (second  DF))
	 (d-n3-tl-22 (seventh DF))
	 (d-n3-tl-31 (sixth   DF))
	 (d-n1-tl    (third   DF))
	 (d-n1-sl-b  (first   DB))
	 (d-n3-22-b  (second  DB))
	 (d-n3-31-b  (third   DB))
	 
	 ;;determine deltas in damping and action
	 (delta-damping (- (damping (+ (N3) d-n3)) (damping (N3))))
	 (delta-action  (action  d-n1-sl   d-n1-tl d-n3-tl-31 d-n3-tl-22 
				 d-n1-sl-b 
				 d-n3-22-b 
				 d-n3-31-b
				 *alpha* *k* *litl*))
	 ;; Determine whether the action is real or imaginary
	 (action-is-imaginary (zerop (realpart delta-action))))
    
    ;;accept with probability as function of changes in action and damping

    ;;this expression assumes that the "delta-action" is the change in
    ;;real-valued euclidean action
    (when (not action-is-imaginary)
	(prog nil
	   (print "Data:")
	   (print (list d-n1-sl d-n1-tl d-n3-tl-31 d-n3-tl-22 
			d-n1-sl-b d-n3-22-b d-n3-31-b *alpha* *k* *litl*))
	   (print "Action:")
	   (print (action  d-n1-sl   d-n1-tl d-n3-tl-31 d-n3-tl-22 
				 d-n1-sl-b 
				 d-n3-22-b 
				 d-n3-31-b
				 *alpha* *k* *litl*))
	   (error "Action must be completely imaginary. Something is wrong."))
	(< (random 1.0) (* (exp (realpart (* *i* delta-action)))
			   (exp (- delta-damping)))))))


;; a sweep is defined as N-INIT number of attempted moves
(defun sweep ()
  (let ((num-attempted 0))
    (while (< num-attempted N-INIT)
      (let* ((sxid (random *LAST-USED-3SXID*))
	     (mtype (select-move))
	     (movedata (try-move sxid mtype)))
	(while (null movedata)
	  (setf sxid (random *LAST-USED-3SXID*)
		mtype (select-move) 
		movedata (try-move sxid mtype)))
	(incf num-attempted) ;; number-of-attempted-moves-counter for this sweep
	(incf (nth mtype ATTEMPTED-MOVES)) ;; number of moves of mtype that have been attempted
	(when (accept-move? mtype sxid)
	  (incf (nth mtype SUCCESSFUL-MOVES)) ;; number of moves of mtype that have succeeded
	  (2plus1move movedata))))))

;; following is to be used for tuning the k0 and k3 parameters
(defun generate-data-console (&optional (start-sweep 1))
  (for (ns start-sweep (+ start-sweep NUM-SWEEPS -1))
       (sweep)
       (when (= 0 (mod ns 10))

;	 (format t "start = ~A end = ~A current = ~A count = ~A ~A\%~%"
;		 start-sweep (+ start-sweep NUM-SWEEPS -1) ns 
;		 (count-simplices-of-all-types) (percent-tv)));SUCCESSFUL-MOVES));(accept-ratios)))
;		 ;(count-simplices-of-all-types) (accept-ratios)))

	 (format t "start = ~A end = ~A current = ~A count = ~A ~$\%~%"
		 start-sweep (+ start-sweep NUM-SWEEPS -1) ns 
		 (count-boundary-vs-bulk) (percent-tv)))

       (finish-output)))

;; generate-data should be called after setting the values for eps, k0, k3,
;; NUM-SWEEPS and calling one of the initialize-xx-slices.
(defun generate-data (&optional (start-sweep 1))
  (setf SIM-START-TIME (cdt-now-str))
  (let ((datafilestr (concatenate 'string (generate-filename start-sweep) 3SXEXT))
	(progfilestr (concatenate 'string (generate-filename start-sweep) PRGEXT))
	(end-sweep (+ start-sweep NUM-SWEEPS -1)))
    (for (ns start-sweep end-sweep)
	 (sweep)
	 (when (= 0 (mod ns SAVE-EVERY-N-SWEEPS))
	   (with-open-file (datafile datafilestr 
				     :direction :output
				     :if-exists :supersede)
	     (save-spacetime-to-file datafile))
	   (with-open-file (progfile progfilestr
				     :direction :output
				     :if-exists :supersede)
	     (format progfile "start = ~A end = ~A current = ~A count = ~A~%"
		     start-sweep end-sweep ns (count-simplices-of-all-types)))))))

;; generate-data-v2 is similar to generate data except it creates a fresh data file every 
;; SAVE-EVERY-N-SWEEPS. since a fresh datafile is created, there is no need to maintain a seprate progress
;; file.
(defun generate-data-v2 (&optional (start-sweep 1))
  (setf SIM-START-TIME (cdt-now-str))
  (let ((end-sweep (+ start-sweep NUM-SWEEPS -1)))
    (when (= 1 start-sweep)
      (with-open-file (datafile (concatenate 'string (generate-filename-v2 start-sweep 0) 3SXEXT)
				:direction :output
				:if-exists :supersede)
	(save-spacetime-to-file datafile))
      (for (ns start-sweep end-sweep)
	   (sweep)
	   (when (= 0 (mod ns SAVE-EVERY-N-SWEEPS))
	     (with-open-file (datafile (concatenate 'string (generate-filename-v2 start-sweep ns) 3SXEXT)
				       :direction :output
				       :if-exists :supersede)
	       (save-spacetime-to-file datafile)))))))

;; generate-movie-data saves number of simplices every SAVE-EVERY-N-SWEEPS
(defun generate-movie-data (&optional (start-sweep 1))
  (setf SAVE-EVERY-N-SWEEPS 10)
  (let ((moviefilestr (concatenate 'string (generate-filename start-sweep) MOVEXT))
	(trackfilestr (concatenate 'string (generate-filename start-sweep) PRGEXT))
	(end-sweep (+ start-sweep NUM-SWEEPS -1)))

    ;; open and close the file for :append to work
    (with-open-file (moviefile moviefilestr 
			       :direction :output
			       :if-exists :supersede)
      ;; record the initial data only if start-sweep = 1
      (when (= start-sweep 1)

	(for (ts 0 (1- NUM-T))
	     (format moviefile "~A " (count-simplices-in-sandwich ts (1+ ts))))
	(format moviefile "~%")))
    
    (for (ns start-sweep end-sweep)
	 (sweep)
	 (when (= 0 (mod ns SAVE-EVERY-N-SWEEPS))
	   (with-open-file (moviefile moviefilestr 
				      :direction :output
				      :if-exists :append)
	     (for (ts 0 (1- NUM-T))
		  (format moviefile "~A " (count-simplices-in-sandwich ts (1+ ts))))
	     (format moviefile "~%"))
	   (with-open-file (trackfile trackfilestr
				      :direction :output
				      :if-exists :supersede)
	     (format trackfile "start = ~A end = ~A current = ~A count = ~A~%"
		     start-sweep end-sweep ns (count-simplices-of-all-types)))))))

(defun generate-movie-data-console (&optional (start-sweep 1))
  (when (= 1 start-sweep)
    (reset-move-counts))
  (let ((end-sweep (+ start-sweep NUM-SWEEPS -1)))
       (for (ns start-sweep end-sweep)
	   (sweep)
	   (when (= 0 (mod ns 10))
	     (format t "~A/~A " ns end-sweep)
	     (for (ts 0 (1- NUM-T))
		  (format t "~A " (count-simplices-in-sandwich ts (1+ ts))))
	     (format t "~A ~A~%" (count-simplices-of-all-types) (accept-ratios))))))

(defun generate-spacetime-and-movie-data (&optional (start-sweep 1))
  (let* ((end-sweep (+ start-sweep NUM-SWEEPS -1))
	 (datafilestr (concatenate 'string (generate-filename start-sweep) 3SXEXT))
	 (trackfilestr (concatenate 'string (generate-filename start-sweep) PRGEXT))
	 (moviefilestr (concatenate 'string (generate-filename start-sweep) MOVEXT)))
    
    ;; open and close the file, for :append to work properly
    (with-open-file (moviefile moviefilestr 
			       :direction :output
			       :if-exists :supersede)
      ;; record the initial data only if start-sweep = 1
      (when (= 1 start-sweep)
	(for (ts 0 (1- NUM-T))
	     (format moviefile "~A " (count-simplices-in-sandwich ts (1+ ts))))
	(format moviefile "~%")))
    
    (for (ns start-sweep end-sweep)
	 (sweep)
	 (when (= 0 (mod ns SAVE-EVERY-N-SWEEPS))
	   (with-open-file (datafile datafilestr 
				     :direction :output
				     :if-exists :supersede)
	     (save-spacetime-to-file datafile))
	   
	   (with-open-file (trackfile trackfilestr
				      :direction :output
				      :if-exists :supersede)
	     (format trackfile "~A/~A/~A ~A~%" start-sweep ns end-sweep (count-simplices-of-all-types)))
	   
	   (with-open-file (moviefile moviefilestr 
				      :direction :output
				      :if-exists :append)
	     (for (ts 0 (1- NUM-T))
		  (format moviefile "~A " (count-simplices-in-sandwich ts (1+ ts))))
	     (format moviefile "~%"))))))

(defun 3sx2p1->2sx2p1 (infile outfile)
  "3sx2p1->2sx2p1 generates the 2-simplex information for each spatial slice from the 3-simplex data for
the entire spacetime. The generated information is written to outfile"
  (load-spacetime-from-file infile)
  (clrhash *ID->SPATIAL-2SIMPLEX*)
  (for (ts 0 (1- NUM-T))
       (let ((31simplices (get-simplices-in-sandwich-of-type ts (1+ ts) 3))
	     (spatial-triangles '()))
	 (dolist (31simplex 31simplices)
	   (push (make-s2simplex ts (3sx-lopts (get-3simplex 31simplex))) spatial-triangles))
	 (connect-spatial-2simplices-within-list spatial-triangles)))
  (save-s2simplex-data-to-file outfile))

#|
(defun calculate-order-parameter (&optional (start-sweep 1))
  (let* ((end-sweep (+ start-sweep NUM-SWEEPS -1))
	 (order-parameter 0.0)
	 (datafilestr (format nil 
			      "~A-~A-op-T~A_V~A_eps~A_kz~A_kt~A_sweeps~Ato~A.op" 
			      *topology* *boundary-conditions*
			      NUM-T N-INIT eps k0 k3 start-sweep end-sweep))
	 (trackfilestr (format nil 
			       "~A-~A-op-T~A_V~A_eps~A_kz~A_kt~A_sweeps~Ato~A.progress" 
			       *topology* *boundary-conditions*
			       NUM-T N-INIT eps k0 k3 start-sweep end-sweep)))
    (do ((ns start-sweep (1+ ns)) 
	 (tot 0.0 (incf tot (/ N3-TL-22 (N3)))))
	((> ns end-sweep) (setf order-parameter (/ tot NUM-SWEEPS)))
      (sweep)
      (when (= 0 (mod ns SAVE-EVERY-N-SWEEPS))
	(with-open-file (trackfile trackfilestr
				   :direction :output
				   :if-exists :supersede)
	  (format trackfile "start = ~A end = ~A current = ~A~%"
		  start-sweep end-sweep ns))))
    (with-open-file (datafile datafilestr
			      :direction :output
			      :if-exists :supersede)
      (format datafile "T=~A V=~A eps=~A k0=~A k3=~A start=~A end=~A op=~A~%" 
	      NUM-T N-INIT eps k0 k3 start-sweep end-sweep order-parameter))))

(defun calculate-volume-volume-correlator (&optional (start-sweep 1))
  (let* ((end-sweep (+ start-sweep NUM-SWEEPS -1))
	 (vvparams (make-array (+ NUM-T 1) :initial-element 0.0))
	 (dfilestr (format nil 
			   "~A-~A-vv-T~A_V~A_eps~A_kz~A_kt~A_sweeps~Ato~A.vv" 
			   *topology* *boundary-conditions*
			   NUM-T N-INIT eps k0 k3 start-sweep end-sweep))
	 (tfilestr (format nil 
			   "~A-~A-vv-T~A_V~A_eps~A_kz~A_kt~A_sweeps~Ato~A.prog" 
			   *topology* *boundary-conditions*
			   NUM-T N-INIT eps k0 k3 start-sweep end-sweep)))
    (do ((ns start-sweep (1+ ns)))
	((> ns end-sweep)
	 (do ((j 0 (1+ j))) ((> j NUM-T))
	   (setf (aref vvparams j) 
		 (/ (aref vvparams j) (* NUM-T NUM-T (/ NUM-SWEEPS 100))))))
      (sweep)
      (when (= 0 (mod ns SAVE-EVERY-N-SWEEPS))
	(do ((col 0 (incf col))) ((> col NUM-T))
	  (do ((ts 1/2 (1+ ts))) ((> ts NUM-T))
	    (incf (svref vvparams col)
		  (* (count-simplices-at-time ts)
		     (count-simplices-at-time-pbc (+ ts
						     (- col (/ NUM-T 2))))))))
	(with-open-file (tfile tfilestr 
			       :direction :output 
			       :if-exists :supersede)
	  (format tfile "start = ~A end = ~A current = ~A~%"
		  start-sweep end-sweep ns))))
    (with-open-file (dfile dfilestr
			   :direction :output
			   :if-exists :supersede)
      (format dfile "T=~A V=~A eps=~A k0=~A k3=~A start=~A end=~A vvp=~A~%" 
	      NUM-T N-INIT eps k0 k3 start-sweep end-sweep vvparams))))

(defun compute-spatial-slice-hausdorff-dimension ()
  "compute the hausdorff dimension of all the spatial slices")

(defun compute-thin-sandwich-hausdorff-dimension ()
  "a thin sandwich consists of two adjacent spatial slices")

(defun compute-spacetime-hausdorff-dimension ()
  "the hausdorff dimension of the entire spacetime")

(defun compute-spatial-slice-spectral-dimension ()
  "compute the spectral dimension of all the spatial slices")

(defun compute-thin-sandwich-spectral-dimension ()
  "a thin sandwich consists of two adjacent spatial slices")

(defun compute-spacetime-spectral-dimension ()
  "the spectral dimension of the entire spacetime")

|#
