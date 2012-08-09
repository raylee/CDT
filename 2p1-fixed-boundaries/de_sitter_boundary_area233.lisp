;281;0c;;;; default_script.lisp
;;;; Jonah Miller (jonah.miller@colorado.edu)
;;;; Date: July 12, 2012

;;;; This is a script to test the behaviour of my bug fix and update
;;;; of David Kamensky's 2p1-fixed-boundaries code to work with Rajesh
;;;; Kommu's updated data structures and bug fixes.

;; Load the simulation environment
(load "cdt2p1.lisp")

;; Set the number of sweeps to 10000
(setf NUM-SWEEPS 50000)

;; Initialize a small spacetime for exploratory calculations
(initialize-t-slices-with-v-volume :num-time-slices          18
				   :target-volume            26698
				   :spatial-topology         "s2"
				   :boundary-conditions      "open"
                                   :initial-spatial-geometry "~/CDT_data/de_sitter_BC/TS2-V64-k1.0-kkk0.7577200487786184d0-tslice0-bottom.boundary"
				   :final-spatial-geometry   "~/CDT_data/de_sitter_BC/TS2-V64-k1.0-kkk0.7577200487786184d0-tslice0-bottom.boundary")

;; Initialize the coupling constants to a set that should get us
;; (hopefully) get us onto the critical surface in the k0-k3 phase diagram

;; alpha is set to -1 for consistency. Other values are possible.
(set-k0-k3-alpha 1.0 0.75772 -1)

;; Take data!
(generate-data)