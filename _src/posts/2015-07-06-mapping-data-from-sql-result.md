    Title: Mapping data from sql result to struct
    Date: 2015-07-06T19:15:05
    Tags: racket

<p class="lead"> This post describe the implementation of a descriptive macro to
fill structures from sql result.  </p>

<br/>

##The goal

At end of this post we will archive this:

```racket
;; assume the table actor exist and have at least id, name, age

(struct actor ([id #:auto] [name #:auto] [age #:auto]) 
  #:transparent #:mutable #:auto-value #f)

(select
    (["id" actor id]
     ["name" actor name]
     ["age" actor age])
  "SELECT a.* FROM actor AS a where a.id = $1"
  12)
;; => '(((actor 12 "some name" 80)))
```

<!-- more -->

It easily creates struct out of sql result.

##Implementation

First the mapping function, for every row create the defined struct, and apply
the setter according to column name.

```racket
(require db)

;; a parameter to not have to pass around the database connection.
(define current-database-connection (make-parameter #f))

(define (select-fn mapping request . args)
  ;; Return the list in order of the select column name
  (define (header->name header)
    (map (lambda (x) (cdr (assoc 'name x))) header))
  ;; Run the sql query get the data and the header
  (match-define (struct rows-result ((app header->name headers) data))
    (apply query (list* (current-database-connection) request args)))
  ;; Build the struct and make their instances available from their constructor
  ;; procedure
  (define (build-structs)
    (for/hash ([constructor (in-set (list->set (map third mapping)))])
      (values constructor (constructor))))
  ;; A structure that map every index to the setter and constructor procedure
  (define to-mappeds (let loop ([names (for/hash ([mapped mapping])
                                         (values (first mapped) (rest mapped)))]
                                [indice 0]
                                [headers headers]
                                [result #hash()])
                       (if (or (empty? headers) (hash-empty? names))
                           result
                           (let* ([header (first headers)]
                                  [present (hash-ref names header #f)])
                             (loop
                              (if present (hash-remove names header) names)
                              (add1 indice)
                              (rest headers)
                              (if present (hash-set result indice
                                                    (hash-ref names header))
                                  result))))))
  (define length-row (length headers))
  (for/list ([row data])
    ;; build a new set of structure for each row
    (define structs (build-structs))
    ;; for each column fetch the relevant struct instance and apply its setter
    (for ([(name to-mapped) to-mappeds])
      ((first to-mapped)
       (hash-ref structs (second to-mapped))
       (vector-ref row name)))
    (hash-values structs)))
```

```racket
;; and an example to make the thing clearer
(select-fn (list
             (list "id" set-actor-id! actor)
             (list  "name" set-actor-name! actor)
             (list "age" set-actor-age! actor)
             (list "gender" set-actor-gender! actor))
           "SELECT a.* FROM actor AS a")
```

Second the syntax transformer, the bare minimal to output the example above:

```racket
(begin-for-syntax
  (require syntax/parse
           racket/string))

(define-syntax (select stx)
  (syntax-parse stx
    [(_ stmt:str args ...)
     #`(query (current-database-connection) stmt #,@#'(args ...))]
    [(_ (attributes ...) stmt:str args ...)
     #`(select-fn
        (list
         #,@(map
             (lambda (x)
               (let* ([lst (syntax->list x)]
                      [setter (string-append "set-" 
                                             (symbol->string (syntax-e (cadr lst)))
                                             "-" 
                                             (symbol->string (syntax-e (caddr lst)))
                                             "!")])
                 (list #'list (car lst) (datum->syntax x (string->symbol setter)) (cadr lst))))
             (syntax->list #'(attributes ...))))
        stmt
        #,@#'(args ...))]))
```

##Shortcoming and evolution

The first shortcoming is the relying on mutable and empty constructor fields,
using the struct-info it should be possible to make the link between the field
name and the position but probably can't specify a non-empty constructor will
not be missing arguments at runtime.

Its is not possible to use multiple time the same struct definition:

```racket
(select
    (["id" actor id]
     ["name" actor name]
     ["age" actor age]
     ["b_id" actor id]
     ["b_name" actor name]
     ["b_age" actor age])
  "SELECT a.*, b.id as b_id, b.name as b_name, b.age as b_age FROM actor AS a FROM actor AS b")
```

The two actor will be conflicting, we need to specify which one we want to be
filled with, for example like:

```racket
(select
  ((actor "mister a"
     ["id" id]
     ["name" name]
     ["age" age])
   (actor "mister b"
     ["b_id" id]
     ["b_name" name]
     ["b_age" age]))
  "SELECT a.*, b.id as b_id, b.name as b_name, b.age as b_age FROM actor AS a FROM actor AS b")
```

As shown with the example above the column with same name is problematic, its
need to be explicitly changed "b.id AS b_id".

Extract knowledge from the SQL string and apply some checks, and go even further
with an awareness of the schema.

