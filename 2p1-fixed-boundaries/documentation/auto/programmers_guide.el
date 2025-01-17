(TeX-add-style-hook "programmers_guide"
 (lambda ()
    (LaTeX-add-labels
     "s:intro"
     "s:lisp:tricks"
     "s:lisp:tools"
     "s:algorithm"
     "s:data-structures"
     "ss:points"
     "s:links-edges"
     "sss:sl1simplex:id"
     "sss:tl1simplex:id"
     "s:data:tetrahedra"
     "s:d:tetrahedra:access"
     "s:f-and-b-vectors"
     "s:functions"
     "s:f:metropolis:loop"
     "s:initialization"
     "s:initialization:top-level"
     "f:itswvv"
     "s:initialization:mid-level-functions"
     "sss:triangulate-between-slices"
     "fig:pseudo-face-decomposition"
     "fig:pseudo-face-complices"
     "sec:grow-spacetime"
     "sec:load-from-file"
     "subsec:output"
     "sec:output-new-files"
     "sec:output:appending-to-files")
    (TeX-run-style-hooks
     "graphicx"
     "hyperref"
     "color"
     "listings"
     "verbatim"
     "fullpage"
     "latex2e"
     "art12"
     "article"
     "12pt")))

