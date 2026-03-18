(sb-ext:restrict-compiler-policy 'speed 3 3)
(sb-ext:restrict-compiler-policy 'debug 0 0)
(sb-ext:restrict-compiler-policy 'safety 0 0)
(setf *block-compile-default* t)

(ql:quickload :cl-mpm/examples)
(in-package :cl-mpm/examples)

(setf cl-mpm/settings::*optimise-setting* cl-mpm/settings::*optimise-speed*)

(defun main (&optional args)
	(load "template.lisp"))

(sb-ext:save-lisp-and-die
   "worker"
    :executable t
    :toplevel #'main
    :compression nil
    :save-runtime-options t
    )
(uiop:quit)
