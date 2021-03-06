(in-package :cepl.c-arrays)

;;------------------------------------------------------------

(defn subseq-c ((array c-array) (start c-array-index)
                &optional (end c-array-index))
    c-array
  "This function returns a c-array which contains
   a subset of the array passed into this function.
   Right this will make more sense with a use case:

   Imagine we have one gpu-array with the vertex data for 10
   different monsters inside it and each monster is made of 100
   vertices. The first mosters vertex data will be in the
   sub-array (gpu-sub-array bigarray 0 1000) and the vertex
   data for the second monster would be at
   (gpu-sub-array bigarray 1000 2000)

   This *view* (for lack of a better term) into our array can
   be really damn handy. Prehaps, for example, we want to
   replace the vertex data of monster 2 with the data in my
   c-array newmonster. We can simply do the following:
   (push-g (gpu-sub-array bigarray 1000 2000) newmonster)

   Obviously be aware that any changes you make to the parent
   array affect the child sub-array. This can really bite you
   in the backside if you change how the data in the array is
   laid out."
  (declare (optimize (speed 3) (safety 1) (debug 1)))
  (declare (profile t))
  (let* ((dimensions (c-array-dimensions array))
         (length (the c-array-index (first dimensions)))
         (elem-size (c-array-element-byte-size array)))
    (assert (= (length dimensions) 1) ()
            "Cannot take subseq of multidimensional array")
    (assert (and (< start end) (< start length) (<= end length)) ()
            "Invalid subseq start or end for c-array")
    (%make-c-array
     :pointer (cffi:inc-pointer (c-array-pointer array)
                                (* elem-size start))
     :dimensions (list (- end start))
     :total-size (c-array-total-size array)
     :element-byte-size (c-array-element-byte-size array)
     :element-type (c-array-element-type array)
     :struct-element-typep (c-array-struct-element-typep array)
     :row-byte-size (c-array-row-byte-size array)
     :element-from-foreign (c-array-element-from-foreign array)
     :element-to-foreign (c-array-element-to-foreign array))))

(defmethod pull1-g ((object c-array))
  (let* ((dimensions (c-array-dimensions object))
         (depth      (1- (length dimensions)))
         (indices    (make-list (1+ depth))))
    (labels ((recurse (n)
               (loop for j below (nth n dimensions)
                     do (setf (nth n indices) j)
                     collect (if (= n depth)
                                 (pull1-g (aref-c* object indices))
                               (recurse (1+ n))))))
      (recurse 0))))

(defmethod pull-g ((object c-array))
  (pull1-g object))

(defmethod push-g (object (destination c-array))
  (unless (or (listp object) (arrayp object))
    (error "Can only push arrays or lists to c-arrays"))
  (c-populate destination object))

(defmethod lisp-type->pixel-format ((type c-array))
  (or (c-array-element-pixel-format type)
      (lisp-type->pixel-format (c-array-element-type type))))

;;------------------------------------------------------------
