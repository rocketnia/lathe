; rel.arc
;
; A type of dependency, given as '(rel "relative/path/to/code.arc"),
; which will load a file from a path relative to the currently loading
; file's path. In order to accomplish this, the load-dir* global
; varible is defined, and it keeps track of the path to the currently
; loading file's directory (relative to the path 'load uses).
;
; It is assumed that the result of loading the file itself will be a
; package. For instance, (activate '(rel "path/whatever.arc")) will
; try to activate the loaded result as a package, and if this doesn't
; work, there will be an error. You can say
; (prepare '(rel "path/whatever.arc")) in order to avoid the
; activation, but this will still place the result in the
; available-packages* list, where it doesn't really belong.
;
; If you don't like any of this hullaballoo, or even if you do, two
; functions are provided to interact with load-dir*: loadrel and
; loadabs. The loadabs function works exactly like load but does the
; proper bookkeeping of load-dir* so that the loaded file can use
; relative paths correctly. The loadrel function does all that but
; itself takes a relative address.

(once-tl "load rel.arc"


(= load-dir* "")

(def split-at-dir (str)
  (catch
    (down i (- len.str 1) 0
      (when (in (call str i) #\/ #\\)
        (throw:split str (+ i 1))))
    (split str 0)))

([push _ car.compile-dependency-rules*]
 (fn (dependency)
   (when (and acons.dependency
              (is car.dependency 'rel)
              (single cdr.dependency))
     (let relpath cadr.dependency
       (when (isa relpath 'string)
         (withs ((reldir filename) split-at-dir.relpath
                 absdir (string load-dir* reldir)
                 abspath (+ absdir filename))
           (obj type 'compiled-dependency
                prepare (fn ()
                          (withs (original loadabs.abspath
                                  result (obj type 'loaded-package
                                              path abspath
                                              original original))
                            (= !activate.result
                               (fn ()
                                 ((!original.result 'activate))))
                            result))
                accepts (fn (package)
                          (and (isa package 'table)
                               (iso !type.package 'loaded-package)
                               (iso !abspath.package abspath))))))))))

(def loadrel (relpath)
  (loadabs:string load-dir* relpath))

(def loadabs (abspath)
  (with ((absdir filename) split-at-dir.abspath
         old-load-dir load-dir*)
    (after
      (do
        (= load-dir* absdir)
        load.abspath)
      (= load-dir* old-load-dir))))

(mac using-rels (relpaths . body)
  (unless alist.relpaths (zap list relpaths))
  `(usings ,(map [do ``(rel ,,_)] relpaths) ,@body))


)