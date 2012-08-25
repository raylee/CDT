;;;; action.lisp
;;;; Author: Jonah Miller (jonah.maxwell.miller@gmail.com)

;;;; This file contains functions that create and modify the action
;;;; used by 2+1 dimensional CDT with fixed boundaries.


;;; The following functions will be used to construct the
;;; action. action-exposed is the form of the action, and this is
;;; where changes to the form of the action should be made. It is not,
;;; however, the action function used in the metropolis
;;; algorithm. Instead, make-action is called by set-k0-k3-alpha (or
;;; alternatively set-k-litL-alpha), which then sets the variable
;;; name, 'action, which was set with defvar above to the proper
;;; function. This saves computational time because alpha, k, and litL
;;; don't have to passed to the function every time, but are still
;;; change-able at run-time. This is a trick that would only work in a
;;; language like lisp, where functions are compiled but an
;;; interpreted environment still exists at runtime.

;; Functional form of the corrected action that uses arbitrary alpha
;; and arbitrary k and lambda. Set ret-coup to true for
;; debugging. Note that the action is purely complex. This is expected
;; after Wick rotation and the correct partition function is e^{i
;; action}. Note that if the b-vector is zero (i.e., there is no
;; boundary, i.e., we have periodic boundary conditions), the action
;; reduces to the bulk action.
(defun action-exposed (num1-sl num1-tl num3-31 num3-22 
	       ; Some additional arguments that need to be passed for
	       ; open boundary conditions. In theory, the number of
	       ; (3,1)-simplices connected to the boundary should be
	       ; looked at too. At the fixed bounary, they don't
	       ; change and have no effect on the dynamics. However at
	       ; the other boundary, which we do not keep fixed, they
	       ; have a substantial effect.
	      num1-sl-top ; spacelike links on top boundary
	      num3-22-top ; (2,2)-simplices connected to top boundary
	      num3-31-top ; (3,1)&(1,3)-simplices connected to top boundary
	      num1-sl-bot ; spacelike links on bottom boundary
	      num3-22-bot ; (2,2)-simplices connected to bottom boundary
	      num3-31-bot ; (3,1)&(1,3)-simplices connected to bottom boundary
	      alpha k litL ; Tuning parameters
	      &optional (ret-coup nil))
  "The action before setting coupling constants."
  (let* ((2alpha+1 (+ (* 2 alpha) 1)) ; self-explanatory
	 (4alpha+1 (+ (* 4 alpha) 1))
	 (4alpha+2 (+ (* 4 alpha) 2))
	 (3alpha+1 (+ (* 3 alpha) 1))
	 ; dihedral angle around spacelike bone for (2,2) simplices
	 (theta-22-sl (asin (/ (* *-i* (wrsqrt (* 8 2alpha+1))) 4alpha+1))) 
	 ; dihedral angle around spacelike bones for (3,1) simplices
	 (theta-31-sl (acos (/ *-i* (wrsqrt (* 3 4alpha+1)))))
	 ;dihedral angle around timelike bones for (2,2) simplices
	 (theta-22-tl (acos (/ -1 4alpha+1)))
	 ; dihedral angle around time-like bones for (3,1) simplices
	 (theta-31-tl (acos (/ 2alpha+1 4alpha+1)))
	 ; 3-volume of a (2,2)-simplex
	 (v3-22 (wrsqrt 4alpha+2))
	 ; 3-volume of a (3,1)- or (1,3)-simplex
	 (v3-31 (wrsqrt 3alpha+1))

	 ;; Coefficients for action assuming closed manifold.

	 ;; BULK

         ; spacelike edges term (for total angle we take the deficit from)
	 (K1SL (* *pi/i* k)) 
	  ; timelike edges term (for the total angle we take deficit from)
	 (K1TL (* (wrsqrt alpha) 2 pi k))  
	 ; coefficient for (2,2)-simplices around spacelike bone term
	 (K3SL-22 (* -1  (/ k *i*) theta-22-sl))  
	 ; coefficient for dihedral angle of (3,1)-simplices at each edge.
	 (K3SL-31 (* -1 3 (/ k *i*) theta-31-sl))  
	 ; term for dihedral angle around timelike edges of (2,2)-simplices
	 (K3TL-22 (* -4 (wrsqrt alpha) k theta-22-tl)) 
	 ; term for dihedral angle around timelike edges of (1,3)- and
	 ; (3,1)-simplices
	 (K3TL-31 (* -3 k (wrsqrt alpha) theta-31-tl)) 
	 (KV22 (* -1 (/ litL 12) v3-22)) ; volume term for (2,2)-simplices
	 (KV31 (* -1 (/ litL 12) v3-31)) ; volume term for (3,1)-simplices

	 ;; BOUNDARY

	 (B1SL (* k (/ pi *i*))) ; term for sum over spacelike edges
	 ; term for sum over dihedral angles of (3,1)-simplices at each bone.
	 (B3SL-31 (* -1 *2/i* k theta-31-sl)) 
	 ; term for sum over dihedral angles of (2,2)-simplices
	 ; attached at each bone
	 (B3SL-22 (* -1 (/ k *i*) theta-22-sl))) 

    ;; JM: Note that I keep track of both boundaries separately, even
    ;; though this isn't really necessary. This is for clarity and in
    ;; case my conception of the action is incorrect, changes are
    ;; easier.	     

    (if ret-coup ; if ret-coup, just return debugging info. Otherwise,
		 ; return the action.
;;	(list (* 2 K1SL) K1TL
;;	      (+ K3SL-31 K3TL-31 KV31) (+ (* 2 K3SL-22) K3TL-22 KV22)
;;	      K3SL-31 K3TL-31 KV31)
;;	(list theta-22-sl theta-31-sl theta-22-tl theta-31-tl
;;	      v3-22 v3-31 K1SL K1TL K3SL-22 K3TL-22 K3TL-31 KV22 KV31
;;	      B1SL B3SL-31 B3SL-22)
	(list  (+ (* 2 K3SL-22) K3TL-22 KV22) (* 2 K3SL-22) K3TL-22 KV22)

	(+ ;; BULK TERM
	 ; we need to subtract the boundary simplices from the bulk
	 (* K1SL (- (* 2 num1-sl) (+ num1-sl-top num1-sl-bot)))
	 (* K1TL num1-tl) ; there are no boundary timelike simplices 

	 ; We subtract half of the (2,2)-simplices at the boundary
	 ; because each (2,2)-simplex at the boundary contributes one
	 ; dihedral angle to the bulk sum and one dihedral angle to
	 ; the boundary sum, while (2,2)-simplices in the bulk
	 ; contribute 2 dihedral angles to the bulk sum.
	 (* K3SL-22 (- (* 2 num3-22) (+ num3-22-top num3-22-bot)))
	 ; For (3,1)-simplices attacked to the boundary, we have the
	 ; same problem as with (2,2)-simplices.
	 (* K3SL-31 (- num3-31 (+ num3-31-top num3-31-bot)))
	 ; There are no timelike bones in the boundary, so we don't
	 ; have to subtract for angles around timelike bones.
	 (* K3TL-31 num3-31) 
	 (* K3TL-22 num3-22)
	 ; volume terms
	 (* KV22 num3-22)
	 (* KV31 num3-31)

	 ;; BOUNDARY TERM
	 ;; top boundary
	 (* B1SL num1-sl-top) ; pi term for deficit angle
	 (* B3SL-31 num1-sl-top) ; (3,1)-simplex contribution to deficit angle
	 (* B3SL-22 num3-22-top) ; (2,2)-simplex contribution to deficit angle
	 ;; bottom boundary
	 (* B1SL num1-sl-bot) ; pi term for deficit angle
	 (* B3SL-31 num1-sl-bot) ; (3,1)-simplex contribution to deficit angle
	 (* B3SL-22 num3-22-bot))))) ; (2,2)-simplex contribution to
		                     ; deficit angle
	  
(defun make-action (alpha k litL)
  "Construct an action with fixed coupling constants 
for use in the simulation."
  (setf (symbol-function 'action)
	#'(lambda (num1-sl num1-tl num3-31 num3-22
		   num1-sl-top num3-22-top num3-31-top
		   num1-sl-bot num3-22-bot num3-31-bot)
	    (action-exposed num1-sl num1-tl num3-31 num3-22
			    num1-sl-top num3-22-top num3-31-top
			    num1-sl-bot num3-22-bot num3-31-bot 
			    alpha k litL))))

;;; Functions to set coupling constants and build action. Both
;;; functions are equivalent. They just take different inputs.

;; Takes k0-k3-alpha as input, sets k, lambda, alpha, k0, k3, and then
;; constructs an action and initializes moves.
(defun set-k0-k3-alpha (k0 k3 alpha)
  (setf *k0* k0 *k3* k3 *alpha* alpha)
  (setf *k* (/ *k0* (* 2 *a* pi)))
  (setf *litL* (* (- *k3* (* 2 *a* pi *k* 3KAPPAMINUS1)) 
		  (/ 6ROOT2 (* *a* *a* *a*))))
  (make-action *alpha* *k* *litL*)
  (initialize-move-markers))

;; Function analogous to set-k0-k3-alpha, but takes k, litL, and alpha
;; as inputs.
(defun set-k-litL-alpha (k litL alpha)
  (prog nil
     (setf *k* k
	   *litL*  litL
	   *alpha* alpha)
     (setf *k0* (* *k* (* 2 *a* pi))
	   *k3* (+ (/ (* *litL* *a* *a* *a*) 6ROOT2) 
		   (* 2 *a* pi *k* 3KAPPAMINUS1)))
     (make-action *alpha* *k* *litL*)
     (initialize-move-markers)))

;; JM: Deprecated. I've replaced this with the functions
;; above. However, for completeness and for debugging, I've left the
;; original function in here. A warning: IT DOES NOT CONSTRUCT AN
;; ACTION WITH THE BOUNDARY CONDITION TERM INCLUDED.
(defun set-k0-k3-alpha-deprecated (kay0 kay3 alpha)
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

