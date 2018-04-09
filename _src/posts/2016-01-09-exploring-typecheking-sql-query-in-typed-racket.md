    Title: exploring typecheking sql query in typed/racket
    Date: 2016-01-09T18:48:19
    Tags: racket

<p class="lead"> This post will describe a <abbr title="Proof Of Concept">POC</abbr>
on how to typecheck sql query in typed/racket. </p>

<br/>

The goal is to make this typecheck:

```racket
(: some-query : (Listof (Vector String String)))
(define some-query
  (query
   movies
   #:from     ([actor a] [movie m])
   #:where    (= a.name "Jhon Wayne")
   #:select   (a.name m.name)))
```

With the schema defined as:

```racket
(define-schema movies
  (actor    [id Integer]
            [name String])
  (movie    [id Integer]
            [name String]
            [director_id Integer])
  (director [id Integer]
            [name String]))
```

<!-- more -->

This <abbr title="Proof Of Concept">POC</abbr> already take me too much time so
there will be shortcomings the full source code is available
[here](/code/typed-db.rkt) and its [example](/code/typed-db-example.rkt).


## The define-schema macro

This macro will define a syntax transformer retaining the schema information to
be used later by the <code>query</code> macro. The type of the columns didn't
reflect any SQL type it is just typed/racket types, user defined types could be
used also.

The code isn't worth commenting the expanded code will be:

```racket
(define-syntax movies
  (schema-st 
   (list 
    'movies
    (quote-syntax
     ((actor ((id Integer) (name String)))
      (movie ((id Integer) (name String) (director_id Integer)))
      (director ((id Integer) (name String))))))))
      
(define-for-syntax (struct schema-st (data) #:property prop:procedure (lambda (st) (schema-st-data st))))
```

This is completely straight forward it defines a <code>movie</code> transformer
that retains data available for other macros.

For shortcoming reasons it's unclear if using the struct schema is necessary or
if <code>(define-syntax movies (list ...))</code> would have done the trick.

Also, the data structure shouldn't have been a complete syntax object of the whole
schema information but just a syntax object of the types, like:

```racket
`(movies
  ((actor ((id ,#'Integer) (name ,#'String)))
   (movie ((id ,#'Integer) (name ,#'String) (director_id ,#'Integer)))
   (director ((id ,#',#'Integer) (name ,#'String)))))
```

And it also could output type alias to have abstract type:

```racket
(define-type movies.actor.id Integer)
(define-type movies.actor.name String)
(define-type movies.movie.id Integer)
;;...
```

## The query macro

Copied the example here to refresh your mind.

```racket
(: some-query : (Listof (Vector String String)))
(define some-query
  (query
   movies
   #:from     ([actor a] [movie m])
   #:where    (= a.name "Jhon Wayne")
   #:select   (a.name m.name)))
```

This one take the definition by whatever you have named it, <code>movies</code>
in this case. It will fetch the schema definition thought
<code>syntax-local-value</code> so you have to pass the <code>movies</code>
every time you use the <code>query</code> macro.

As you would expect this macro check that <code>#:from</code> and
<code>#:select</code> are present only once, bark if an alias isn't defined for
each table, for select and where it checks the columns <code>name</code> are
present in table <code>actor</code> and <code>movie</code>.

The expanded code isn't even useful just to ensure the typecheking mechanism
works.

The two interesting parts are:

- It uses <code>ann</code> on the where expression to ensure it has the type of
  <code>a.name</code> so it gives <code>(ann "Jhon Wayne" String)</code>
  
- It uses <code>cast</code> on the query result and generate runtime assertion on
  every rows. Typed/racket didn't provide an <code>unsafe-cast</code> form yet.

The expansion could look like:

```racket
(: some-query : (Listof (Vector String String)))
(define some-query
  (cast (exec-query 
         "SELECT a.name, m.name FROM actor AS a, movie AS m WHERE a.name = ?"
         (ann "Jhon Wayne" String))
        (Listof (Vectorof String String))))
```

## Conclusion

1. Using <code>cast</code> could be costly maybe generate our own guard with
   predicate could reduce this cost. 

2. Have to pass the schema definition to every <code>query</code> could be
   tedious and inelegant. Maybe <code>racket/stxparam</code> could help or maybe
   <code>define-schema</code> should generate a transformer
   <code>query-movies</code> that is like <code>query</code> without the
   <code>movie</code> part.
   
3. The <code>query</code> <abbr title="Domain Specific Language">DSL</abbr> is
   redundant with SQL because it's already a DSL. It may be possible to use a
   reader for SQL something like <code>#sql"SELECT * FROM table"</code>.
   
4. The types of the schema information didn't reflect the SQL type, the ability
   to pass any kind of type alone isn't useful, it should also pass two
   procedures one to convert from the complex type to some SQL representation
   and the inverse. Example: if you want to use json in some column
   <code>option</code> of type <code>TEXT</code> the definition should be
   <code>[options Json read-json write-json]</code>.

5. All this is an awful lot of works. :)
