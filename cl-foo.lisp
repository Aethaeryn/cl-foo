;;;; This file uses the functionality provided by this game engine
;;;; library to make a very simple demo of its capabilities.

(in-package #:cl-foo)

;;; Yes, I know this looks ugly. It's temporary.
(defparameter *shaders*
  (list (make-instance 'shader
                       :type :vertex-shader
                       :source '((:version 330)
                                 (:defvar position :vec4 :storage in :location 0)
                                 (:defvar offset :vec4 :storage uniform)
                                 (:defvar view-matrix :mat4 :storage uniform)
                                 (:defvar projection-matrix :mat4 :storage uniform)
                                 (:defun main :void ()
                                         (:setf gl-position (:* projection-matrix
                                                                view-matrix
                                                                (:+ position offset))))))
        (make-instance 'shader
                       :type :fragment-shader
                       :source '((:version 330)
                                 (:defvar out-color :vec4 :storage out)
                                 (:defun main :void ()
                                         (:setf out-color (:vec4 0.5 0.5 1.0 1.0)))))))

;;; Note: SDL doesn't like it if the program is made fullscreen when
;;; the resolution is not the monitor's current resolution, at least
;;; on my machine.
(defun main-loop (&key (width 1280) (height 720) (title "OpenGL Rendering Test") (fullscreen nil))
  (with-sdl2 (window :title title :width width :height height)
    (if fullscreen (sdl2:set-window-fullscreen window 1))
    (with-buffers (buffers :count 2)
      (with-shaders (shaders program *shaders*)
        (let* ((camera (make-instance 'camera))
               (cube-group (get-cube-group 10 10 10 :offset #(0.0 -4.0 -10.0 0.0)))
               (vao (make-instance 'vao
                                   :program program
                                   :array-buffer (elt buffers 0)
                                   :element-array-buffer (elt buffers 1)
                                   :array (elt cube-group 1)
                                   :element-array (elt cube-group 0)
                                   :in-variable 'position)))

          ;; Sets the parts of the program that don't need to be
          ;; updated constantly in the loop.
          (with-shader-program (program)
            (uniform-matrix program 'projection-matrix (perspective-matrix 45.0 (/ width height) 0.1 200.0))
            (uniform-vector program 'offset #(1.0 -2.0 -10.0 0.0)))

          ;; Things to update while looping.
          (with-game-loop (window keydown-scancodes)
            (if keydown-scancodes (map nil
                                       #'(lambda (scancode) (move-camera camera scancode))
                                       keydown-scancodes))
            (with-shader-program (program)
              (uniform-matrix program 'view-matrix (camera-matrix camera)))
            (use-vao vao)))))))
