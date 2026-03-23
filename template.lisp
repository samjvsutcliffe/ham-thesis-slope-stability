(in-package :cl-mpm/examples/ice/slope-stability)
(defparameter *refine* (parse-float:parse-float (if (uiop:getenv "REFINE") (uiop:getenv "REFINE") "1")))
(let ((threads (parse-integer (if (uiop:getenv "OMP_NUM_THREADS") (uiop:getenv "OMP_NUM_THREADS") "16"))))
  (setf lparallel:*kernel* (lparallel:make-kernel threads :name "custom-kernel"))
  (format t "Thread count ~D~%" threads))

(defun run (&key (output-dir (format nil "./output/"))
              (csv-dir nil)
              (csv-filename (format nil "load-disp.csv")))
  (unless csv-dir
    (setf csv-dir output-dir) )

  (ensure-directories-exist output-dir)
  (ensure-directories-exist csv-dir)
  (let ((eps (cl-mpm/penalty::bc-penalty-epsilon *penalty*)))
    (setf (cl-mpm/penalty::bc-penalty-epsilon *penalty*) 1d-15)
    (cl-mpm/dynamic-relaxation::elastic-static-solution
     *sim*
     :elastic-solver (type-of *sim*))
    (setf (cl-mpm/penalty::bc-penalty-epsilon *penalty*) eps))
  (let* ((lstps 50)
         (total-disp -1d0)
         (current-disp 0d0)
         (disp-0 (cl-mpm::reduce-over-mps (cl-mpm:sim-mps *sim*)
                                          (lambda (mp)
                                            (cl-mpm/utils:get-vector (cl-mpm/particle::mp-displacement mp) :y))
                                          #'min))
         (step 0))
    (defparameter *data-disp* (list))
    (defparameter *data-load* (list))
    (push disp-0 *data-disp*)
    (push (get-load) *data-load*)

    (loop for f in (uiop:directory-files (uiop:merge-pathnames* "./outframes/")) do (uiop:delete-file-if-exists f))

    (vgplot:close-all-plots)
    (time
     (cl-mpm/dynamic-relaxation::run-adaptive-load-control
      *sim*
      :output-dir output-dir
      :plotter (lambda (sim))
      :loading-function
      (lambda (i)
        (setf current-disp (+ (* i total-disp) disp-0))
        (cl-mpm/penalty::bc-set-displacement
         *penalty*
         (cl-mpm/utils:vector-from-list (list 0d0 current-disp 0d0))))
      :post-conv-step
      (lambda (sim)
        (push current-disp *data-disp*)
        (let ((load (get-load)))
          (format t "Load ~E~%" load)
          (push load *data-load*))
        (save-csv csv-dir csv-filename *data-disp* *data-load*)
        (incf step))
      :load-steps lstps
      :max-adaptive-steps 20
      :enable-plastic t
      :enable-damage t
      :damping 1d0;(sqrt 2d0)
      :max-damage-inc 0.2d0
      :substeps 50
      :criteria 1d-3
      :save-vtk-dr nil
      :save-vtk-loadstep t
      :dt-scale 1d0))))

(setup :refine *refine*
       :l-scale (* *refine* 1d0)
       :angle 16.7d0
       :angle-r 10d0
       :gf 10000d0
       :mps 4
       :rt 1d0
       :rc 0.9d0)
;(setf (cl-mpm::sim-ghost-factor *sim*) nil
;      (cl-mpm/aggregate::sim-enable-aggregate *sim*) t)
;(setf (cl-mpm/damage::sim-enable-length-localisation *sim*) t)
(setf (cl-mpm/damage::sim-enable-ekl *sim*) t)
(run :output-dir (format nil "./data/output-~E/" *refine*))
