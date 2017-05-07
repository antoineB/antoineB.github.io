#lang typed/racket #:no-optimize

(provide exec-query
         define-schema
         query)

(require (for-syntax racket/string racket/list syntax/parse))

;; a stub should be better done latter
(: exec-query : String -> (Listof Any))
(define (exec-query sql)
  (list))

(begin-for-syntax
  (provide (struct-out schema-st))
  (struct schema-st (data) #:property prop:procedure (lambda (st) (schema-st-data st))))

(define-for-syntax (parse-table stx)
  (syntax-parse stx
    [(table-name (column-name type) ...)
     (list
      ;; define table
      (list (syntax->datum #'table-name)
            (map (lambda (column)
                   (let ([column (syntax->list column)])
                     (list
                      (syntax->datum (car column))
                      (cadr column))))
                 (syntax->list #'((column-name type) ...))))
      ;; define types (unused now but convenient in case the type change (you
      ;; have to update all the query type))
      (map (lambda (column)
             (let ([column (syntax->list column)])
               #`(define-type
                   #,(datum->syntax
                      stx
                      (string->symbol
                       (string-append
                        (symbol->string (syntax->datum #'table-name))
                        "."
                        (symbol->string (syntax->datum (car column))))))
                   #,(cadr column))))
           (syntax->list #'((column-name type) ...))))]
    ;; TODO: Do better error message, maybe... later... one day...
    ))


(define-syntax (define-schema stx)
  (syntax-parse stx
    [(_ name tables ...)
     (let* ([tables (map parse-table (syntax->list #'(tables ...)))]
            [def (map car tables)]
            [end #`(begin
                     (define-syntax name
                       (schema-st (list
                                   (quote name)
                                   (quote-syntax #,def)))))])
       end)]))


(define-for-syntax (identifier-name=? a b)
  (equal? (syntax->datum a) (syntax->datum b)))

(define-for-syntax (check-keyword stx)
  (define keywords (group-by values (syntax->list stx) identifier-name=?))
  (define select-ok #f)
  (define from-ok #f)
  (for ([keyword keywords])
    (when (> 1 (length keyword))
      ;; TODO: give the position where the other one appear
      (raise-syntax-error #f "The keyword should appear only once" stx (car keyword)))
    (let* ([keyword (car keyword)]
           [sym (syntax->datum keyword)])
      (when (not (member sym '(#:select #:from #;join #;left-join #:where #;group-by)))
        (raise-syntax-error #f (format "The keyword ~a is not expected bitch" sym)
                            stx
                            keyword))
      (when (equal? sym '#:select) (set! select-ok #t))
      (when (equal? sym '#:from) (set! from-ok #t))))
  (when (or (not select-ok) (not from-ok))
    (raise-syntax-error #f (format "The keyword ~a is required" (if (not select-ok) "#:select" "#:from")) stx)))

(define-for-syntax (schema-get-type schema table column)
  (define (tr-list-assoc lst)
    (map (lambda (x)
           (define lst (syntax->list x))
           (list* (syntax->datum (first lst))
                  (rest lst)))
         lst))
  (define data (tr-list-assoc (syntax->list (cadr schema))))
  (define columns (assoc table data))
  (and columns (cadr (assoc column (tr-list-assoc (syntax->list (cadr columns)))))))

(define-for-syntax (schema-get-columns schema table)
  (define columns (assoc table (syntax->datum (cadr schema))))
  (and columns (map car (cadr columns))))

(define-for-syntax (schema-get-tables schema)
  (map car (syntax->datum (cadr schema))))

(define-for-syntax (check-double stx)
  (define aliases (group-by values (syntax->list stx) identifier-name=?))
  (for ([alias aliases])
    (when (> 1 (length alias))
      ;; TODO: give the position where the other one appear
      (raise-syntax-error #f "The alias should appear only once" stx (car alias)))))

(define-for-syntax (check-table schema stx)
  (for ([table (syntax->list stx)])
    (when (not (member (syntax->datum table) (schema-get-tables schema)))
      (raise-syntax-error #f "The table is not present in the schema" stx table))))

(define-for-syntax (from-form schema stx)
  (syntax-parse stx
    [((table:id alias:id) ...)
     (check-double #'(alias ...))
     (check-table schema #'(table ...))
     (map
      list
      (map syntax->datum (syntax->list #'(alias ...)))
      (map syntax->datum (syntax->list #'(table ...))))]))

(define-for-syntax (check-select-name stx)
  (when (not (regexp-match? #rx"^([^.]+)[.]([^.]+)$" (symbol->string (syntax->datum stx))))
    (raise-syntax-error #f "The select name is not of the form [alias].[column]" stx)))

(define-for-syntax (get-alias&column stx)
  (define reg (regexp-match #rx"^([^.]+)[.]([^.]+)$" (symbol->string (syntax->datum stx))))
  (define parts (map string->symbol (rest reg)))
  (values (car parts)
          (cadr parts)))


(define-for-syntax (select-form schema from stx)
  (syntax-parse stx
    [(part:id ...)
     (for/list ([part (syntax->list #'(part ...))])
       (check-select-name part)
       (define-values (alias column) (get-alias&column part))
       (define table-name (assoc alias from))
       (when (not table-name)
         (raise-syntax-error #f "The alias is not declared in the from" stx part))
       (define columns (schema-get-columns schema (second table-name)))
       (when (not (member column columns))
         (raise-syntax-error #f "The column is not declared in the table" stx part))
       (list
        (syntax->datum part)
        (schema-get-type schema (second table-name) column)))]))

(define-for-syntax (where-form schema from stx)
  (syntax-parse stx
    #:datum-literals (=)
    [(= name:id ex:expr)
     (check-select-name #'name)
     (define-values (alias column) (get-alias&column #'name))
     (define table-name (assoc alias from))
     (when (not table-name)
       (raise-syntax-error #f "The alias is not declared in the from" stx #'name))
     (define columns (schema-get-columns schema (second table-name)))
     (when (not (member column columns))
       (raise-syntax-error #f "The column is not declared in the table" stx #'name))
     (define type (schema-get-type schema (second table-name) column))
     (list (syntax->datum #'name)
           type
           #'ex)]))


(define-syntax (query stx)
  ;; TODO: do the other form than SELECT and FROM.
  (syntax-parse stx
    [(_ db:id (~seq kw:keyword ex:expr) ...)
     (define schema0 (syntax-local-value #'db))
     (when (not schema0) (raise-syntax-error #f "The schema variable isn't bound" #'db))
     (define schema (schema0))
     (check-keyword #'(kw ...))
     (define parts (for/hash ([entry (syntax->list #'((kw ex) ...))])
                     (let ([parts (syntax->list entry)])
                       (values
                        (syntax->datum (car parts))
                        (cadr parts)))))
     (define from (from-form schema (hash-ref parts '#:from)))
     ;; ((a actor) (m movie))
     (define select (select-form schema from (hash-ref parts '#:select)))
     ;; ((a.name String) (m.name String))
     (define where (and (hash-ref parts '#:where #f) (where-form schema from (hash-ref parts '#:where))))
     (define sql (format "SELECT ~a FROM ~a~a"
                         (string-join (map (compose symbol->string car) select) " ")
                         (string-join (map (lambda (part) (format "~a AS ~a" (car part) (cadr part))) from) " ")
                         (if where
                             (format " WHERE ~a = ?" (symbol->string (first where)))
                             "")))
     #`(begin
         #,sql
         #,(if where #`(ann #,(third where) #,(datum->syntax stx (second where))) #'(void))
         (cast (list (vector "abc" "edf")) (Listof (Vector #,@(map (lambda (x) (datum->syntax stx (cadr x))) select)))))]))
