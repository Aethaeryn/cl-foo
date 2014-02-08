;;;; SHADER.LISP
;;; This file translates s-expressions to GLSL shader strings, which
;;; can then be compiled into OpenGL shaders. It is a work in
;;; progress.

(in-package #:cl-foo)

;;; Note: GLSL uses camelcase for almost everything. The only apparent
;;; exception is things prefixed with gl_.
(defun glsl-name (symbol)
  (let ((camelcase-string (cffi:translate-camelcase-name symbol)))
    (if (cl-ppcre:scan "^gl[A-Z]" camelcase-string)
        (cl-ppcre:regex-replace "^gl" camelcase-string "gl_")
        camelcase-string)))

(defun glsl-element (element)
  (cond
    ((null element) nil)
    ((listp element) (glsl-operator (first element) (rest element)))
    ((symbolp element) (glsl-name element))
    (t element)))

(defun binary-op (symbol-string first-elt rest-elt)
  (let ((control-string (format nil "(~~A~~{ ~A ~~A~~})" symbol-string)))
    (format nil control-string first-elt rest-elt)))

(defun unary-op (symbol-string first-elt)
  (format nil "~A(~A)" symbol-string first-elt))

(defun glsl-function-argument (arg)
  (format nil "~A ~A" (glsl-name (elt arg 1)) (glsl-name (elt arg 0))))

;;; Takes in a name, a type, a list of arguments, and a body and
;;; returns a string representation of a GLSL function. The argument
;;; list can be blank or can be arbitrarily long.
;;;
;;; It takes in typed arguments like defmethod, with each argument
;;; being a list of two symbols, the first as the name and the second
;;; as the type.
(defun glsl-function (name type args body)
  (let ((first-arg (first args))
        (rest-args (rest args)))
    (format nil
            "~%~A ~A(~@[~A~]~{, ~A~})~%{~%~{  ~A~}}"
            (glsl-name type)
            (glsl-name name)
            (if first-arg (glsl-function-argument first-arg))
            (if rest-args (mapcar #'glsl-function-argument rest-args))
            (mapcar #'glsl-line body))))

;;; This line is used to define a GLSL variable of a type and name. If
;;; a location integer is given then the proper syntax is provided for
;;; that. A storage qualifier is typically given. Usually it is "in", "out", or
;;; "uniform".
;;;
;;; See https://www.opengl.org/wiki/Type_Qualifier_%28GLSL%29#Storage_qualifiers
(defun glsl-var (name type &key storage location)
  (format nil
          "~@[layout(location = ~D) ~]~@[~A ~]~A ~A;~%"
          location
          (if storage (glsl-name storage) nil)
          (glsl-name type)
          (glsl-name name)))

;;; Either something is a C/C++ style operator or it is actually a
;;; function call. If it is a C/C++ style operator then it's either a
;;; binary one that can be applied arbitrarily or a unary one that can
;;; only take one argument.
(defun glsl-operator (symbol l)
  (let ((first-elt (glsl-element (first l)))
        (rest-elt (mapcar #'glsl-element (rest l))))
    (case symbol
      ((:+) (binary-op "+" first-elt rest-elt))
      ((:*) (binary-op "*" first-elt rest-elt))
      ((:/) (binary-op "/" first-elt rest-elt))
      ((:>) (binary-op ">" first-elt rest-elt))
      ((:<) (binary-op "<" first-elt rest-elt))
      ((:>=) (binary-op ">=" first-elt rest-elt))
      ((:<=) (binary-op "<=" first-elt rest-elt))
      ((:and) (binary-op "&&" first-elt rest-elt))
      ((:or) (binary-op "||" first-elt rest-elt))
      ((:not) (unary-op "!" first-elt))
      ((:-) (if (= (length rest-elt) 0)
                (unary-op "-" first-elt)
                (binary-op "-" first-elt rest-elt)))
      ;; Call function SYMBOL with optional first parameter and
      ;; optional later parameters.
      (otherwise (format nil "~A(~@[~A~]~{, ~A~})" (glsl-name symbol) first-elt rest-elt)))))

;;; The s-expressions are a one-line-operation, a function, or an
;;; in-line operation or function call.
(defun glsl-line (l)
  (let ((symbol (elt l 0)))
    (case symbol
      ((:version) (format nil "#version ~D~%~%" (elt l 1)))
      ((:defvar) (glsl-var (elt l 1) (elt l 2)
                           :storage (getf (nthcdr 3 l) :storage)
                           :location (getf (nthcdr 3 l) :location)))
      ((:setf) (format nil "~A = ~A;~%" (glsl-name (elt l 1)) (glsl-element (elt l 2))))
      ((:defun) (glsl-function (elt l 1) (elt l 2) (elt l 3) (nthcdr 4 l)))
      (otherwise (glsl-operator symbol (rest l))))))

;;; Use this to make a shaders string from a list of lists.
(defun make-glsl-shader (l)
  (format nil "~{~A~}" (mapcar #'glsl-line (cons '(:version 330) l))))

(defclass shader ()
  ((source
    :initarg :source
    :accessor shader-source
    :initform (error "You need to provide the source for the shader."))
   (shader-type
    :initarg :type
    :accessor shader-type
    :initform (error "You need to provide the type for the shader."))))

(defmethod initialize-instance :after ((shader shader) &key)
  (setf (slot-value shader 'source) (make-glsl-shader (slot-value shader 'source))))
