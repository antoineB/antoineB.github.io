#lang typed/racket #:no-optimize

(require "typed-db.rkt")


(define-schema movies
  (actor    [id Integer]
            [name String])
  (movie    [id Integer]
            [name String]
            [director_id Integer])
  (director [id Integer]
            [name String]))


(: some-query : (Listof (Vector String String)))
(define some-query
  (query
   movies
   #:from     ([actor a] [movie m])
   #:select   (a.name m.name)))
