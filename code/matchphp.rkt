#lang racket

(define (read-char-n in n)
  (string-join
   (for/list ([n (range n)])
     (string->immutable-string (string (read-char in))))
   ""))

(define (lexer in)
  (define rules
    '((#rx"^\\( *int *\\)" TYPE_INT)
      (#rx"^\\( *bool *\\)" TYPE_BOOL)
      (#rx"^\\( *string *\\)" TYPE_STRING)
      (#rx"^\\( *resource *\\)" TYPE_RESOURCE)
      (#rx"^\\( *float *\\)" TYPE_FLOAT)
      (#rx"^\\( *array *\\)" TYPE_ARRAY)
      (#rx"^\\( *object *\\)" TYPE_OBJECT)
      (#rx"^\\( *object *\\)" TYPE_MIXED)
      (#rx"^[\n\t\r\f ]+" BLANK)
      (#rx"^//[^\n]*\n" COMMENT)
      (#rx"^/[*].*?[*]/" COMMENT)
      (#rx"^\"[^\"]*\""  STRING)
      (#rx"^'[^']*'" STRING)
      (#rx"^[0-9]+" INTEGER)
      (#rx"^[$][a-zA-Z_][a-zA-Z0-9_]*" VARIABLE)
      (#rx"^," COMMA)
      (#rx"^\\(" OPAREN)
      (#rx"^\\)" CPAREN)
      (#rx"^\\[" OBRACKET)
      (#rx"^\\]" CBRACKET)
      (#rx"^\\|\\|" OR)
      (#rx"^&&" AND)
      (#rx"^{" OBRACE)
      (#rx"^}" CBRACE)
      (#rx"^=>" ARROW)
      (#rx"^->" OBJECT_ARROW)
      (#rx"^[a-zA-Z_][a-zA-Z_0-9]+" IDENT)
      (#rx"^:" COLON)
      (#rx"^£[^£]+£" CODE)))
  (define (inner-lex in)
    (define (next-token)
      (for/first ([candidate rules]
                  #:when (regexp-match-peek (first candidate) in))
        (list (second candidate)
              (bytes->string/utf-8 (first (regexp-match (first candidate) in))))))
    (let loop ([token (next-token)]
               [tokens empty])
      (match token
        [#f tokens]
        [(list 'CBRACE _) (cons token tokens)]
        [(list (or 'BLANK 'COMMENT) _) (loop (next-token) tokens)]
        [else (loop (next-token) (cons token tokens))])))
  (let loop
      ([ok (regexp-match-peek-positions #rx"match[\n\t\r\f ]*\\(" in)]
       [result empty])
    (if (not ok)
        (reverse (cons (port->string in) result))
        (let ([res (read-char-n in (caar ok))]
              [tokens (inner-lex in)])
          (loop
           (regexp-match-peek-positions #rx"match[\n\t\r\f ]*\\(" in)
           (append tokens (list res) result))))))

(define (parse-variable var)
  (substring var 1))

(define (parse-code code)
  (substring code 1 (sub1 (string-length code))))

(define (bad-syntax tokens)
  (raise (format "bad syntax ~a"
                 (take (map
                        (lambda (x) (if (pair? x) (car x) (substring x 0 10)))
                        tokens)
                       (min (length tokens) 10)))))

(define (parse-match tokens)
  (match tokens
    [(list-rest (list _ "match")
                (list 'OPAREN _)
                (list 'CODE code)
                (list 'CPAREN _)
                (list 'OBRACE _)
                inner ...
                (list 'CBRACE _)
                rst)
     (string-append
      (let ([clauses (parse-clause inner)])
        (format
         "
       $__MATCH__expr = ~a;
       $__MATCH__variables = [];
       $__MATCH__result = true; // usefull for nested pattern
       ~a
       switch (true) {
       ~a
       }
       "
         (parse-code code)
         (string-join (map car clauses) "\n")
         (string-join (map cdr clauses) "\n")))
      (parse-match rst))]
    [(list-rest (? string? str) rst)
     (string-append str (parse-match rst))]
    [(list)
     ""]
    [else
     (bad-syntax tokens)]))


(define (parse-clause tokens [nb 0])
  (match tokens
    [(list-rest (list _ "case")
                (and (not (list 'COLON _)) pattern) ...
                (list 'COLON _)
                (list 'CODE code)
                rst)
     (cons
      (cons
       (format
        " $__MATCH__case~a = function ($__MATCH__expr) use (&$__MATCH__variables, &$__MATCH__result) {
              $__MATCH__inner_variables = [];
              $__MATCH__result = true;
              ~a
              if ($__MATCH__result === true) {
                $__MATCH__variables = array_merge($__MATCH__variables, $__MATCH__inner_variables);
              }
                return $__MATCH__result;
           }; "
        nb
        (parse-pattern pattern))
       (format
        " case $__MATCH__case~a($__MATCH__expr):
              extract($__MATCH__variables);
              ~a"
        nb
        (parse-code code)))
      (parse-clause rst (add1 nb)))]
    [(list-rest (list _ "default")
                (list 'COLON _)
                (list 'CODE code)
                rst)
     (cons
      (cons
       (format " $__MATCH__case~a = function ($__MATCH__expr) { return true; }; " nb)
       (format
        " case $__MATCH__case~a($__MATCH__expr):
              extract($__MATCH__variables);
              ~a"
        nb
        (parse-code code)))
      (parse-clause rst (add1 nb)))]
    [(list)
     (list)]
    [else
     (bad-syntax tokens)]))

(define (parse-type-check str)
  (case str
    [(TYPE_INT) "is_int($__MATCH__expr)"]
    [(TYPE_FLOAT) "is_float($__MATCH__expr)"]
    [(TYPE_STRING) "is_string($__MATCH__expr)"]
    [(TYPE_RESOURCE) "is_resource($__MATCH__expr)"]
    [(TYPE_ARRAY) "is_array($__MATCH__expr)"]
    [(TYPE_OBJECT) "is_object($__MATCH__expr)"]
    [(TYPE_BOOL) "is_bool($__MATCH__expr)"]
    [(TYPE_MIXED) "true"]
    [else (raise (format "Unknown type ~a" str))]))

(define (parse-pattern tokens)
  (match tokens
    [(list (or (list 'IDENT "null")
               (list 'IDENT "true")
               (list 'IDENT "false")
               (list 'INTEGER _)
               (list 'STRING _)))
     (format
      " if ($__MATCH__result === true) {
                if ($__MATCH__expr !== ~a) {
                  $__MATCH__result = false;
                 }
              } "
      (cadar tokens))]
    [(list (or (list 'IDENT "null")
               (list 'IDENT "true")
               (list 'IDENT "false")
               (list 'INTEGER _)
               (list 'STRING _))
           (list 'IDENT "as") (list 'VARIABLE var))
     (format
      " if ($__MATCH__result === true) {
                if ($__MATCH__expr === ~a) {
                  $__MATCH__inner_variables['~a'] = $__MATCH__expr;
                 } else {
                  $__MATCH__result = false;
                 }
              } "
      (cadar tokens)
      (parse-variable var))]
    [(list (list (or 'TYPE_INT 'TYPE_FLOAT 'TYPE_STRING 'TYPE_MIXED 'TYPE_RESOURCE 'TYPE_ARRAY 'TYPE_OBJECT) _)
           (list 'IDENT "as") (list 'VARIABLE var))
     (format
      " if ($__MATCH__result === true) {
                if (~a) {
                  $__MATCH__inner_variables['~a'] = $__MATCH__expr;
                 } else {
                  $__MATCH__result = false;
                 }
              } "
      (parse-type-check (caar tokens))
      (parse-variable var))]
    [(list (list (or 'TYPE_INT 'TYPE_FLOAT 'TYPE_STRING 'TYPE_MIXED 'TYPE_RESOURCE 'TYPE_ARRAY 'TYPE_OBJECT) _))
     (format
      " if ($__MATCH__result === true) {
                if (!~a) {
                  $__MATCH__result = false;
                 }
              } "
      (parse-type-check (caar tokens)))]
    [(list (list 'IDENT "instanceof")
           (list 'IDENT classname)
           (list 'OPAREN _)
           inner ...
           (list 'CPAREN _)
           (list 'IDENT "as")
           (list 'VARIABLE var))
     (parse-instanceof classname inner (parse-variable var))]
    [(list (list 'IDENT "instanceof")
           (list 'IDENT classname)
           (list 'OPAREN _)
           inner ...
           (list 'CPAREN _))
     (parse-instanceof classname inner #f)]
    ;; [(list (list 'IDENT "array") (list 'OPAREN _) inner ... (list 'CPAREN _))
    ;;  ]
    ;; [(list (list 'IDENT "array") (list 'OPAREN _) inner ... (list 'CPAREN _) (list 'IDENT "as") (list 'VARIABLE var))
    ;;  ]
    ;; [(list (list 'OBRACKET _) inner ... (list 'CBRACKET _))
    ;;  ]
    ;; [(list (list 'OBRACKET _) inner ... (list 'CBRACKET _) (list 'IDENT "as") (list 'VARIABLE var))
    ;;  ]

    [else (bad-syntax tokens)]))

;; Separate on comma to have subpattern more easy to parse with match (comma
;; appear only in paren and bracket), just give the first subpattern.
;;
;; Return values of the tokens and rest
(define (separate-on-comma tokens stop-token-type [balanced-paren? #t] [balanced-bracket? #t])
  (let loop ([rst tokens]
             [paren 0]
             [bracket 0]
             [result empty])
    (match rst
      [(list-rest (and (list token-type _) token) rst)
       (if (and (equal? paren 0)
                (equal? bracket 0)
                (equal? stop-token-type token-type))
           (values (reverse result) rst)
           (loop rst paren bracket (cons token result)))]
      [(list) (values (reverse result) empty)]
      [(list-rest (and (list 'OPAREN _) token) rst)
       #:when (and balanced-paren? (equal? 0 bracket))
       (loop rst (add1 paren) bracket (cons token result))]
      [(list-rest (and (list 'CPAREN _) token) rst)
       #:when (and balanced-paren? (equal? 0 bracket))
       (loop rst (sub1 paren) bracket (cons token result))]
      [(list-rest (and (list 'OBRACKET _) token) rst)
       #:when (and balanced-bracket? (equal? 0 paren))
       (loop rst paren (add1 bracket) (cons token result))]
      [(list-rest (and (list 'CBRACKET _) token) rst)
       #:when (and balanced-bracket? (equal? 0 paren))
       (loop rst paren (sub1 bracket) (cons token result))]
      [(list-rest token rst)
       (loop rst paren (cons token result))])))


(define (parse-instanceof classname inner var)
  (define property-code " if ($__MATCH__result === true) {
              if (isset($__MATCH__expr->{'~a'})) {
                $__MATCH__tmp_val = $__MATCH__expr->{'~a'}; // if it as side effect
                // function is necessary to reduce variables scope
                $__MATCH__tmp_fun = function ($__MATCH__expr) use (&$__MATCH__inner_variables, &$__MATCH__result) {
                ~a
                };
                $__MATCH__tmp_fun($__MATCH__tmp_val);
             } else {
                 $__MATCH__result = false;
             }
           } ")
  (define method-code " if ($__MATCH__result === true) {
              if (method_exists($__MATCH__expr, '~a')) {
                $__MATCH__tmp_val = $__MATCH__expr->{'~a'}(~a);
                // function is necessary to reduce variables scope
                $__MATCH__tmp_fun = function ($__MATCH__expr) use (&$__MATCH__inner_variables, &$__MATCH__result) {
                ~a
                };
                $__MATCH__tmp_fun($__MATCH__tmp_val);
             } else {
                 $__MATCH__result = false;
             }
           } ")
  (define (parse-array-key tokens)
    (define (next rst fmt . args)
      (define-values (pattern rest) (separate-on-comma rst 'COMMA))
      (define pattern-text (parse-pattern pattern))
       (cons
        (apply format (append (cons fmt args)
                              (list pattern-text)))
        (parse-array-key rest)))
    (match tokens
      [(list-rest (list 'OBJECT_ARROW _)
                  (list 'IDENT ident)
                  (list 'OPAREN _)
                  (list 'CODE code)
                  (list 'CPAREN _)
                  (list 'ARROW _)
                  rst)
       (next rst method-code ident ident (parse-code code))]
      [(list-rest (list 'OBJECT_ARROW _)
                  (list 'IDENT ident)
                  (list 'OPAREN _)
                  (list 'CPAREN _)
                  (list 'ARROW _)
                  rst)
       (next rst method-code ident ident "")]
      [(list-rest (list 'OBJECT_ARROW _)
                  (list 'IDENT ident)
                  (list 'ARROW _)
                  rst)
       (next rst property-code ident ident)]
      [(list) empty]
      [else
       (bad-syntax tokens)]))
  (format
   " if ($__MATCH__result === true) {
       if ($__MATCH__expr instanceof ~a) {
         ~a
         ~a
       } else {
         $__MATCH__result = false;
       }
   } "
   classname
   (string-join (parse-array-key inner) "\n")
   (if var (format " if ($__MATCH__result === true) { $__MATCH__inner_variables['~a'] = $__MATCH__expr; } "
                   var)
       "")))


 (define (extract-match in)
   (define tokens (lexer in))
   (parse-match tokens))

(module+ main
  (require racket/cmdline)
  (command-line
   #:program "PHP prepro"
   #:args (input output)
   (call-with-output-file
     #:exists 'replace
     output
     (lambda (out)
       (display
        (extract-match (open-input-file input))
        out)))))
