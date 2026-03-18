(in-package :cl-mpm/examples/ice/slope-stability)
(defparameter *refine* (parse-float:parse-float (if (uiop:getenv "REFINE") (uiop:getenv "REFINE") "1")))
(let ((threads (parse-integer (if (uiop:getenv "OMP_NUM_THREADS") (uiop:getenv "OMP_NUM_THREADS") "16"))))
  (setf lparallel:*kernel* (lparallel:make-kernel threads :name "custom-kernel"))
  (format t "Thread count ~D~%" threads))

(defun run (&key (output-dir (format nil "./output/"))
              (csv-dir (format nil "./output/"))
              (csv-filename (format nil "load-disp.csv")))

  (ensure-directories-exist output-dir)
  (ensure-directories-exist csv-dir)
  (cl-mpm/dynamic-relaxation::elastic-static-solution
   *sim*)
  (let* ((lstps 50)
         (total-disp -1d0)
         (current-disp 0d0)
         (disp-0 (cl-mpm::reduce-over-mps (cl-mpm:sim-mps *sim*)
                                          (lambda (mp)
                                            (cl-mpm/utils:get-vector (cl-mpm/particle::mp-displacement mp) :y))
                                          #'min))
         (step 0))
    (defparameter *data-disp* (list 0d0))
    (defparameter *data-load* (list 0d0))
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
      :max-adaptive-steps 10
      :enable-plastic t
      :enable-damage t
      :damping 1d0;(sqrt 2d0)
      :max-damage-inc 0.5d0
      :substeps 10
      :criteria 1d-3
      :save-vtk-dr t
      :save-vtk-loadstep t
      :dt-scale 1d0))))

(setup :refine *refine*)
(run :output-dir (format nil "./data/output-~E/" *refine*))
