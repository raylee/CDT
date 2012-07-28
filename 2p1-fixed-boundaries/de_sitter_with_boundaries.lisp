;;;; default_script.lisp
;;;; Jonah Miller (jonah.miller@colorado.edu)
;;;; Date: July 12, 2012

;;;; This is a script to test the behaviour of my bug fix and update
;;;; of David Kamensky's 2p1-fixed-boundaries code to work with Rajesh
;;;; Kommu's updated data structures and bug fixes.

;; Load the simulation environment
(load "cdt2p1.lisp")

;; Set the number of sweeps to 10000
(setf NUM-SWEEPS 50000)

;; Save every 500 sweeps
(setf SAVE-EVERY-N-SWEEPS 500)

;; Initialize a small spacetime for exploratory calculations
(with-open-file (infile "S2-OPEN-T028-V030853-1.0-0.75772-0.02--1-000000001-000033000-000050000-on-bloch-start2012-07-19-16-46-34-curr2012-07-20-19-43-56.3sx2p1")
  (load-spacetime-from-file infile))

;; Initialize the coupling constants to a set that should get us
;; (hopefully) get us onto the critical surface in the k0-k3 phase diagram

;; alpha is set to -1 for consistency. Other values are possible.
(set-k0-k3-alpha 1.0 0.75772 -1)
;(set-k0-k3-alpha 1.0 0.862 -1)

;; Take data!
(generate-data-v2)