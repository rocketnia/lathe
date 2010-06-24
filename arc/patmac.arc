; patmac.arc
;
; A patmac is a function (assumed pure) tagged with 'patmac that takes
; some unevaluated arguments in a pattern DSL and returns a
; two-element list containing a list of variables to bind and an Arc
; expression describing a function that, when applied to the subject
; of this part of the pattern, returns an iterable (see iter.arc) over
; tables which determine what the bound variables are bound to.
;
; TODO: Describe more.

(packed:using-rels-as ut "utils.arc"
                      ir "iter.arc"


; === Infrastructure =================================================

(=fn my.get-patmac (name)
  (unless anormalsym.name
    (err:+ "The name given to 'get-patmac was nil, an ssyntax "
           "symbol, or a non-symbol."))
  (iflet globalname my.patmacs*.name
    (or (check global.globalname [isa _ 'patmac])
        (err:+ "A registered patmac (" name ") wasn't of the patmac "
               "type."))
    (let result global!globalname
      (when (isa result 'patmac) result))))

; TODO: See if this could support (a:b c) syntax. It would have to
; check the op for a (compose a b) format.
(=fn my.patcompile (pat)
  (if acons.pat
    (let (op . args) pat
      (zap expand op)
      (iflet op-value my.get-patmac.op
        (apply rep.op-value args)
        (list nil (cons op args))))
      anormalsym.pat
    (list list.pat `[,ir!iterify (list:obj ,pat _)])
    (list nil pat)))

; This table maps symbols for use in patterns to global names bound to
; patmacs. For instance, (cons something something) might be a pattern
; syntax which is compiled by some global patmac 'cons-patmac. To let
; that happen, this table can map the symbol 'cons to the symbol
; 'cons-patmac.
(= my.patmacs* (table))

(=mc my.patmc (parms . body)
  `(annotate 'patmac (fn ,parms ,@body)))

(=mc my.=patmc (name parms . body)
  `(= ,name (,my!patmc ,parms ,@body)))

(=mc my.named-patmac (arc-name pat-name parms . body)
  (zap ut.deglobalize-var arc-name)
  `(do1 (,my!=patmc ,arc-name ,parms ,@body)
        (= (,my!patmacs* ',pat-name) ',arc-name)))

(=mc my.patmac (name parms . body)
  (zap ut.deglobalize-var name)
  `(,my!named-patmac ,name ,name ,parms ,@body))


; === Utilities for using patterns ===================================

(=mc my.patdsl (pat)
  (cadr my.patcompile.pat))

(=mc my.some-match (pat subject . body)
  (let (locals patexpr) my.patcompile.pat
    (w/uniq g-pat
      `(,ir!iter-somelet ,g-pat ((do ,patexpr) ,subject)
         (apply (fn ,locals ,@body) (map ,g-pat ',locals))))))

(=mc my.all-match (pat subject . body)
  `(no (,my!some-match ,pat ,subject (~do ,@body))))

(=mc my.each-match (pat subject . body)
  `(,my!some-match ,pat ,subject ,@body nil))

(=mc my.if-match (pat subject then . elses)
  (let (locals patexpr) my.patcompile.pat
    (w/uniq g-pat
      `(iflet (,g-pat) (call:call:call ,patexpr ,subject)
         (apply (fn ,locals ,then) (map ,g-pat ',locals))
         ,@elses))))

(=mc my.when-match (pat subject . body)
  `(,my!if-match ,pat ,subject (do ,@body)))

(=mc my.patmatch (pat subject)
  `((,my!patdsl ,pat) ,subject))

(=mc my.case-match (subject . body)
  (w/uniq g-subject
    `(let ,g-subject ,subject
       ,(ut:xloop body body
          (if no.body
            nil
              single.body
            car.body
            (let (pat then . elses) body
              `(,my!if-match ,pat ,g-subject
                 ,then
                 ,do.next.elses)))))))


; === Utility patmacs ================================================

(my:named-patmac my.qq-patmac quasiquote (form)
  my.fn-qq-patmac.form)

(=fn my.fn-qq-patmac (form (o nesting 1))
  (if (< nesting 1)
    (err "The nesting level of a pattern quasiquote was too small.")
      (and (is nesting 1) (caris form 'unquote-splicing))
    ; We only support unquote-splicing so that we can have patterns
    ; that match quasiquote forms by way of nested quasiquotes.
    (err "Patterns don't actually support unquote-splicing.")
      (and (is nesting 1) (caris form 'unquote))
    (let cdr-form cdr.form
      (unless single.cdr-form
        (err:+ "A pattern unquote expected 1 parameter and got the "
               "parameter list '" form))
      (my.patcompile car.cdr-form))
    (if acons.form
      (let (car-form . cdr-form) form
        (with ((carlocals carexpr) (my.fn-qq-patmac car-form nesting)
               (cdrlocals cdrexpr) (my.fn-qq-patmac cdr-form
                                     (+ nesting
                                       (case car-form
                                         quasiquote        1
                                         unquote           -1
                                         unquote-splicing  -1
                                                           0))))
          (list (union is carlocals cdrlocals)
                `(with (carexpr ,carexpr cdrexpr ,cdrexpr)
                   [if atom._
                     ,ir!empty-iter
                     (with (carresult (do.carexpr car._)
                            cdrresult (do.cdrexpr cdr._))
                       (,ir!mappendinglet carentry carresult
                         (,ir!mapping [,ut!tab+ carentry _]
                           cdrresult)))]))))
      (list nil `[,ir!iterify (when (is _ ',form) (list:table))]))))

(my:named-patmac my.quote-patmac quote (form)
  (list nil `[,ir!iterify (when (iso _ ',form) (list:table))]))

; This is provided to make it easier to use patterns that don't have a
; static way to determine the variables they bind, such as patterns
; that are given as parameters and patterns that are stored and used
; later.
(my:named-patmac my.binding-patmac binding (form . locals)
  (unless (all anormalsym locals)
    (err:+ "At least one of a 'binding pattern's locals was nil, an "
           "ssyntax symbol, or a non-symbol."))
  (list locals (cadr my.patcompile.form)))

(my:named-patmac my.or-patmac or args
  (let compiled-args (map my.patcompile args)
    (list (dedup:apply join (map get.0 compiled-args))
          `(let iter-makers (list ,@(map get.1 compiled-args))
             [,ir!mappending ._ iter-makers]))))

(my:named-patmac my.atomic-patmac atomic (form)
  (let (locals patexpr) my.patcompile.form
    ; Jarc doesn't like (do:compose ...).
    (list locals `(do (compose ,ir!stoppingafter1 ,patexpr)))))


)