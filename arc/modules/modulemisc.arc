; modulemisc.arc


; This will evaluate its body, one line at a time, in the top-level
; context. This lets the code modify global bindings even if a lexical
; scope would shadow them. Furthermore, the lexical scope will be
; totally inaccessible.
(mac tldo body
  ; NOTE: In Anarki, [do `(eval ',_)] is nullary thanks to the quote.
  `(do ,@(map (fn (_) `(eval ',_)) body)))


(mac mc (parms . body)
  `(annotate 'mac (fn ,parms ,@body)))

(mac =mc (name parms . body)
  `(= ,name (mc ,parms ,@body)))

(mac =fn (name parms . body)
  `(= ,name (fn ,parms ,@body)))

(mac thunk body
  `(fn () ,@body))


; NOTE: Ar has 'ac-ssyntax instead of 'ssyntax.
(unless bound!ssyntax (if bound!ac-ssyntax (= ssyntax ac-ssyntax)))


; Expand both ssyntax and macros until neither is left.
(def expand (expr)
  (let nextexpr macex.expr
    (if ssyntax.nextexpr
      (expand:ssexpand nextexpr)
      nextexpr)))

; A (call a b c) form should act the same way as a plain (a b c) form,
; *except* when 'a is a symbol globally bound to a macro at the time
; the expression is compiled, in which case (call a b c) will
; effectively suppress that macro expansion.
(def call (f . args)
  (apply f args))

(def anormalsym (x)
  (and x (isa x 'sym) (~ssyntax x)))

; This will transform a list of parameters from
; ((var1 val1 var2 val2) body1 body2) format--as seen in Arc's
; 'with--into a Scheme- or CL-style
; (((var1 val1) (var2 val2)) body1 body2) format. If the pairerr
; argument is provided, that error will be raised if the binding list
; has an odd length.
;
; Furthermore, if the first parameter is *not* a list, this will
; magically find as many bindings from the beginning of the parameter
; list as it can. The only bindings that can be found this way are
; those whose names are non-ssyntax symbols, including the non-ssyntax
; symbol 'nil. If there's an odd number of parameters, the last
; parameter will not be put into a binding, since there's no
; expression to bind it with; instead, it will be part of the body.
;
; The restriction on "magic" binding names means that destructuring
; (which Arc's 'let supports) and setforms (which Arc's '= supports)
; are left out. However, a macro which uses destructuring or setforms
; can still take advantage of parse-magic-withlike, since whenever the
; user of the macro needs those features, he or she can just use
; with-style parentheses.
;
(def parse-magic-withlike (arglist (o pairerr))
  (case arglist nil
    '(())
    (let (first . rest) arglist
      (if alist.first
        (if (and pairerr (odd:len first))
          err.pairerr
          (cons pair.first rest))
        (let withlist (accum acc
                        (while (and cdr.arglist
                                    ((orf no anormalsym) car.arglist))
                          (withs (name pop.arglist val pop.arglist)
                            ; NOTE: Ar parses a.b:c as (a b:c).
                            (do.acc (list name val)))))
          (cons withlist arglist))))))


(def global (name)
  (unless anormalsym.name
    (err "A nil, ssyntax, or non-symbol name was given to 'global."))
  ; NOTE: Rainbow treats a&b.c differently, so we're avoiding it.
  (bound&eval name))

(defset global (name)
  (w/uniq (g-name g-val)
    `(((,g-name ,g-val) (let _ ,name (list _ global._)))
      ,g-val
      ; NOTE: In Anarki, [eval `(= ,,g-name (',thunk._))] is nullary
      ; thanks to the quote.
      (fn (_) (eval `(= ,,g-name (',thunk._)))))))

; NOTE: arc/nu expands a!b to (a (#<box:quote> b)).
(def isa-quote (x)
  ; NOTE: In Jarc 21, !0 uses the symbol |0|.
  ; NOTE: Ar parses a.b:c as (a b:c).
  (in x 'quote (get.0 (get.1 (ssexpand 'a!b)))))

(def safe-deglobalize (var)
  (zap expand var)
  (if anormalsym.var
    var
    
    ; NOTE: Ar doesn't recognize zero-length destructuring forms.
    ; TODO: Replace the below uses of _ with nil.
    
    ; else recognize anything of the form (global 'the-var)
    (catch:withs (_           (unless (caris var 'global) throw.nil)
                  cdr-var     cdr.var
                  _           (unless single.cdr-var throw.nil)
                  cadr-var    car.cdr-var
                  _           (unless (isa-quote car.cadr-var)
                                throw.nil)
                  cdadr-var   cdr.cadr-var
                  _           (unless single.cdadr-var throw.nil)
                  cadadr-var  car.cdadr-var
                  _           (unless anormalsym.cadadr-var throw.nil))
      cadadr-var)
    ))

(def deglobalize (var)
  (or safe-deglobalize.var
      (err:+ "An unrecognized kind of name was passed to "
             "'deglobalize.")))

; Set a global variable temporarily. This is neither thread-safe nor
; continuation-safe, although it will restore the original value of
; the variable upon abnormal exits (as well as normal ones).
;
; This uses 'deglobalize on the variable name, so a namespaced
; variable can be used.
;
(mac w/global (name val . body)
  (zap deglobalize name)
  (w/uniq g-old-val
    `(let ,g-old-val (global ',name)
       (after
         (do (= (global ',name) ,val)
             ,@body)
         (= (global ',name) ,g-old-val)))))

(= read-with-eof
  (case (read (instring "") 'foo) foo
    read
    
    ; Anarki removed the 'eof parameter from 'read.
    (fn ((o stream (stdin)) (o given-eof eof))
      (let result (read stream)
        (if (is result eof)
          given-eof
          result)))))

; This is like 'load, but it returns the result of the final
; expression.
(def loadval (file)
  (with (stream infile.file eof (uniq))
    (let result nil
      (whiler expr (read-with-eof stream eof) eof
        (= result eval.expr))
      result)))
