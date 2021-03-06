; sniff.arc

(packed


; Jarc doesn't support re-invocable continuations, and we don't blame
; it. This flag indicates whether the feature is supported.
(= my.cccraziness* nil)
; NOTE: We'd use catch.throw instead of ccc.idfn here, but Rainbow
; can't handle that. Has Rainbow implemented escape continuations?
; NOTE: On Anarki, [= my.cccraziness* t] is nullary.
(catch:after (ccc.idfn:fn (_) (= my.cccraziness* t)) throw.nil)


; This is based on a bug in official Arc's quasiquote which makes it
; so that `(x . ,y) treats y as a PLT Scheme expression. The bug
; exists on Anarki too.

(=mc my.plt (plt-expr)
  `(cdr `(nil . ,,plt-expr)))

(if (errsafe:is ((eval '(my:plt vector-ref)) my.plt 0) 'tagged)
  (= my.plt* t)
  (=mc my.plt (plt-expr)
    '(err:+ "Dropping to Racket the Arc 3.1 way isn't supported on "
            "this platform.")))


(iflet form (find [unless bound._ (errsafe:eval `(,_ t))]
                    '(ail-code racket))
  (do (= my.ar-plt* t)
      (=mc my.ar-plt (plt-expr)
        `(,form ,plt-expr)))
  (do (= my.ar-plt* nil)
      (=mc my.ar-plt (plt-expr)
        '(err:+ "Dropping to Racket the ar way isn't supported on "
                "this platform."))))


; Jarc and Rainbow each provide their own ways of accessing JVM
; classes. Since they also automatically convert from Arc types to JVM
; types and vice versa, but each using its own rules, it wouldn't be
; easy to make a library totally compatible with them both. Such a
; library would probably provide a wrapper class to make it possible
; to manipulate a return value that would otherwise be coerced to an
; Arc type upon its return, but dealing with those wrapped values
; would be a pain.
;
; Instead, we treat Jarc and Rainbow as separate but very similar
; platforms. The jvm.arc library provides an interface to Java
; classes, fields, and methods which works on both Jarc and Rainbow,
; but the coercions that occur during its method calls are the same
; as the ones that occur during regular Jarc and Rainbow method calls,
; so in many cases it will still be necessary to target some code at
; one platform and some code at another in order to achieve
; platform-independence.
;
; We will set some flags just for that purpose.

(= my.jarcdrop*
  ; NOTE: Jarc handles ~~some-macro:something-else improperly.
  (no:no:errsafe:and (isa java.lang.Class.forName 'fn)
                 (isa java.lang.Class.class 'java.lang.Class)
                 (is ('getName java.lang.Class.class)
                     "java.lang.Class")))

(= my.rainbowdrop*
  ; NOTE: Jarc handles ~~some-macro:something-else improperly.
  (no:no:errsafe:let classclass
                   (java-static-invoke
                     "java.lang.Class" 'forName "java.lang.Class")
    (and (isa classclass 'java-object)
         (classclass 'isInstance classclass))))

(= my.jvm* (or my.jarcdrop* my.rainbowdrop*))


; TODO: Figure out a better way to sniff out ar.
(= my.ardrop* bound!racket-call-with-current-continuation)


)
