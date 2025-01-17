;;;; 120625_test_first_run.lisp
;;;; Author: Jonah Miller (jonah.miller@colorado.edu)
;;;; Date: June 25, 2012

;;;; This is a script to test the behaviour of David Kemansky's code
;;;; now that I know the code works.

;; load the simulation environment
(load "cdt2p1.lisp")
;; Reset the spacetime
(reset-spacetime)
;; Number of sweeps
(setf NUM-SWEEPS 10000)
;; Initialize the desired 3-spacetime topology/initial geometry
(initialize-T-slice-with-V-volume :num-time-slices          64
				  :target-volume            80000
				  :spatial-topology         "s2"
				  :boundary-conditions      "open"
				  :initial-spatial-geometry "tetra.txt"
				  :final-spatial-geometry   "tetra.txt")
;; Initialize coupling constants
(set-k-litL-alpha 0.20 5.00 -1.0)
(generate-spacetime-and-movie-data)
