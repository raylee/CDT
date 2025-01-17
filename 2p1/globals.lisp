;; cdt-2+1-globals.lisp --- all the parameters that might need to be accessed 
;; from multiple files

(setf *random-state* (make-random-state t))

(defparameter *LAST-USED-3SXID* 0)
(defparameter *RECYCLED-3SX-IDS* '())
(defparameter *LAST-USED-POINT* 0)
(defparameter *LAST-USED-S2SXID* 0)

(defmacro next-pt ()
  `(incf *LAST-USED-POINT*))
(defmacro set-last-used-pt (pt)
  `(setf *LAST-USED-POINT* ,pt))
(defmacro next-s2simplex-id ()
  `(incf *LAST-USED-S2SXID*))
(defmacro next-3simplex-id ()
  `(if (null *RECYCLED-3SX-IDS*)
       (incf *LAST-USED-3SXID*)
       (pop *RECYCLED-3SX-IDS*)))
(defmacro recycle-3simplex-id (sxid)
  `(push ,sxid *RECYCLED-3SX-IDS*))

;;------------------------------------------------------------------------------
;; timelike subsimplices have the form (type tmlo (p0 p1 ...))
(defun tlsubsx->id-hashfn (tlsx)
  (sxhash (sort (copy-list (third tlsx)) #'<)))
(defun tlsubsx->id-equality (tlsx1 tlsx2)
  (and (= (first tlsx1) (first tlsx2))
       (= (second tlsx1) (second tlsx2))
       (set-equal? (third tlsx1) (third tlsx2))))
(sb-ext:define-hash-table-test tlsubsx->id-equality tlsubsx->id-hashfn)
(defparameter *TL2SIMPLEX->ID* (make-hash-table :test 'tlsubsx->id-equality))
(defparameter *TL1SIMPLEX->ID* (make-hash-table :test 'tlsubsx->id-equality))
;; spacelike subsimplices have the form (tslice (p0 p1 ...))
(defun slsubsx->id-hashfn (slsx)
  (sxhash (sort (copy-list (second slsx)) #'<)))
(defun slsubsx->id-equality (slsx1 slsx2)
  (and (= (first slsx1) (first slsx2)) 
       (set-equal? (second slsx1) (second slsx2))))
(sb-ext:define-hash-table-test slsubsx->id-equality slsubsx->id-hashfn)
(defparameter *SL2SIMPLEX->ID* (make-hash-table :test 'slsubsx->id-equality))
(defparameter *SL1SIMPLEX->ID* (make-hash-table :test 'slsubsx->id-equality))
;;-----------------------------------------------------------------------------
(defparameter *ID->SPATIAL-2SIMPLEX* (make-hash-table))
(defparameter *ID->3SIMPLEX* (make-hash-table :test 'equal))

(defconstant 26MTYPE 0 "move type (2,6)")
(defconstant 23MTYPE 1 "move type (2,3)")
(defconstant 44MTYPE 2 "move type (4,4)")
(defconstant 32MTYPE 3 "move type (3,2)")
(defconstant 62MTYPE 4 "move type (6,2)")

(defparameter ATTEMPTED-MOVES (list 1 1 1 1 1) 
  "number of attempted moves for each move type")
(defparameter SUCCESSFUL-MOVES (list 1 1 1 1 1) 
  "number of successful moves for each move type")

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

(defparameter DF26 '(1 3 2 2 6 4 0))
(defparameter DF62 '(-1 -3 -2 -2 -6 -4 0))
(defparameter DF44 '(0 0 0 0 0 0 0))
(defparameter DF23 '(0 0 1 0 2 0 1))
(defparameter DF32 '(0 0 -1 0 -2 0 -1))

(defparameter CURRENT-MOVE-IDENTIFIER "UNKNOWN")
(defparameter CURRENT-MOVE-NUMBER 0)
(defparameter STOPOLOGY "unknown" "spatial slice topology --- S2 or T2")
(defparameter BCTYPE "unknown" "boundary conditions --- PERIODIC or OPEN")
(defparameter SAVE-EVERY-N-SWEEPS 10 "save every 10 sweeps by default")
(defparameter NUM-T 666666 
  "number of time slices --- set to a non-zero value so (mod ts NUM-T) works")
(defparameter N-INIT 0 
  "initial volume of spacetime; we try to keep the volume close to this number")
(defparameter NUM-SWEEPS 0 
  "number of sweeps for which the simulation is to run")
(defparameter SIM-START-TIME (cdt-now-str) 
  "set again inside the generate methods for more accurate value")
(defparameter 3SXEXT ".3sx2p1" 
  "used for storing the parameters and 3simplex information")
(defparameter PRGEXT ".prg2p1" 
  "used for keeping track of the progress of a simulation run")
(defparameter MOVEXT ".mov2p1" 
  "used for storing the movie data information")
(defparameter S2SXEXT ".s2sx2p1" 
  "used for storing the spatial 2-simplex information")

;; pi is a builtin constant
(defparameter *k0* 0.0)
(defparameter *k3* 0.0)
(defparameter *eps* 0.02)
(defparameter *a* 1.0)
(defparameter *alpha* -1.0)
(defparameter *i* #C(0.0 1.0)) ;; complex number i
(defparameter *-i* #C(0.0 -1.0)) ;; complex number -i
(defparameter *2/i* (/ 2 *i*))
(defparameter *2pi/i* (* *2/i* pi))
(defparameter *3/i* (/ 3 *i*))
(defparameter ROOT2 (sqrt 2.0))
(defparameter KAPPA (/ (acos (/ 1 3)) pi))
(defparameter 6ROOT2 (* 6.0 ROOT2))
(defparameter 3KAPPAMINUS1 (- (* 3 KAPPA) 1))
;;; wrsqrt is the "wick rotated" sqrt function. Basically wrsqrt(x) = -i*sqrt(-x) when x < 0 and not 
;;; i*sqrt(-x). So wrsqrt(-1) = -i
(defmacro wrsqrt (val)
  `(if (< ,val 0)
       (* -1 ,*i* (sqrt (* -1 ,val)))
       (sqrt ,val)))

(defvar action nil)

;; STOPOLOGY-BCTYPE-NUMT-NINIT-k0-k3-eps-alpha-startsweep-endsweep-hostname-currenttime
(defun generate-filename (&optional (start-sweep 1) (end-sweep (+ start-sweep NUM-SWEEPS -1)))
  (format nil "~A-~A-T~3,'0d-V~6,'0d-~A-~A-~A-~A-~9,'0d-~9,'0d-on-~A-started~A" 
	  STOPOLOGY BCTYPE NUM-T N-INIT *k0* *k3* *eps* *alpha* start-sweep end-sweep (hostname) (cdt-now-str)))

;; STOPOLOGY-BCTYPE-NUMT-NINIT-k0-k3-eps-alpha-startsweep-currsweep-endsweep-hostname-starttime-currenttime
(defun generate-filename-v2 (&optional (ssweep 1) (csweep 0) (esweep (+ ssweep NUM-SWEEPS -1)))
  (format nil "~A-~A-T~3,'0d-V~6,'0d-~A-~A-~A-~A-~9,'0d-~9,'0d-~9,'0d-on-~A-start~A-curr~A" 
	  STOPOLOGY BCTYPE NUM-T N-INIT *k0* *k3* *eps* *alpha* ssweep csweep esweep 
	  (hostname) SIM-START-TIME (cdt-now-str)))

(defvar 26MARKER 0.0)
(defvar 23MARKER 0.0)
(defvar 44MARKER 0.0)
(defvar 32MARKER 0.0)
(defvar 62MARKER 0.0)

(defun damping (num3)
  (* *eps* (abs (- num3 N-INIT))))

(defun initialize-move-markers ()
  (setf 26MARKER 5.0)
  (setf 23MARKER (+ 26MARKER 5.0))
  (setf 44MARKER (+ 23MARKER 5.0))
  (setf 32MARKER (+ 44MARKER 5.0))
  (setf 62MARKER (+ 32MARKER 5.0)))

(defun update-move-markers ()
  (let ((num-successful-moves (apply #'+ SUCCESSFUL-MOVES)))
    (setf 26MARKER (float (/ num-successful-moves 
			     (nth 26MTYPE SUCCESSFUL-MOVES))))
    (setf 23MARKER (+ 26MARKER(float (/ num-successful-moves 
					(nth 23MTYPE SUCCESSFUL-MOVES)))))
    (setf 44MARKER (+ 23MARKER(float (/ num-successful-moves 
					(nth 44MTYPE SUCCESSFUL-MOVES)))))
    (setf 32MARKER (+ 44MARKER(float (/ num-successful-moves 
					(nth 32MTYPE SUCCESSFUL-MOVES)))))
    (setf 62MARKER (+ 32MARKER(float (/ num-successful-moves 
					(nth 62MTYPE SUCCESSFUL-MOVES)))))))

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
  (setf *k0* kay0 *k3* kay3 *alpha* alpha)
  (initialize-move-markers)
  (let* ((k (/ *k0* (* 2 *a* pi)))
	 (litL (* (- *k3* (* 2 *a* pi k 3KAPPAMINUS1)) 
		  (/ 6ROOT2 (* *a* *a* *a*))))
	 (2alpha+1 (+ (* 2 *alpha*) 1))
	 (4alpha+1 (+ (* 4 *alpha*) 1))
	 (4alpha+2 (+ (* 4 *alpha*) 2))
	 (3alpha+1 (+ (* 3 *alpha*) 1))
	 (arcsin-1 (asin (/ (* *-i* (wrsqrt (* 8 2alpha+1))) 4alpha+1)))
	 (arccos-1 (acos (/ *-i* (wrsqrt (* 3 4alpha+1)))))
	 (arccos-2 (acos (/ -1 4alpha+1)))
	 (arccos-3 (acos (/ 2alpha+1 4alpha+1)))
	 (k1SL (* *2pi/i* k))
	 (k1TL (* 2 pi k (wrsqrt *alpha*)))
	 (k3TL31 (+ (* k *3/i* arccos-1) 
		    (* 3 k (wrsqrt *alpha*) arccos-3)
		    (* (/ litL 12) (wrsqrt 3alpha+1))))
	 (k3TL22 (+ (* k *2/i* arcsin-1)
		    (* 4 k (wrsqrt *alpha*) arccos-2)
		    (* (/ litL 12) (wrsqrt 4alpha+2)))))
    (setf (symbol-function 'action)
	  #'(lambda (n1SL n1TL n3TL31 n3TL22)
	      (- (+ (* k1SL n1SL) (* k1TL n1TL)) 
		 (+ (* k3TL31 n3TL31) (* k3TL22 n3TL22)))))))
  
  
;; initialization data

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
(defparameter N3-TL-31-PER-SLICE 4) ; here (3,1) means (3,1), not (3,1)+(1,3)
(defparameter S2-1/2-31 '((1 2 3 5) (2 3 4 6) (3 4 1 7) (4 1 2 8)))
(defparameter S2-1/2-22 '((1 2 5 8) (2 3 5 6) (3 1 5 7) (3 4 6 7) 
			  (4 2 6 8) (4 1 7 8)))
(defparameter S2-1/2-13 '((1 5 7 8) (2 5 6 8) (3 5 6 7) (4 6 7 8)))
