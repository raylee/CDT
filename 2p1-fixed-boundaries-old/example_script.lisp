(load "cdt2p1.lisp")

(reset-spacetime)
(setf NUM-SWEEPS 5000)
(initialize-t-slices-with-v-volume :num-time-slices 64
				   :target-volume 8000
				   :spatial-topology "S2"
				   :boundary-conditions "OPEN")
(setk-litL-alpha 0.2 5.10 -1)
(generate-data-console)
