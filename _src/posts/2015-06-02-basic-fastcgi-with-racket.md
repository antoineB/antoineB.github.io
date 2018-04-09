    Title: basic fastcgi with racket
    Date: 2015-06-02T19:06:53
    Tags: racket


<p class="lead"> The objective is to implement the most basic working fastcgi
protocol in pure racket.  </p>

<br/>

## How it works

The minimal [fastcgi implementation](fastcgi.com/devkit/doc/fcgi-spec.html) will look like:

1. wait on a tcp connection
2. read all input data 
3. write output hello world like data
4. close connection

<!-- more -->

A request is composed of parts denoted here as _segment_. Each
segment is composed of a header of 8 bytes and some data of <var>N</var> bytes and
padding of <var>M</var> bytes where <var>N</var> and <var>M</var> >=0.

The header is:

0. fastcgi version (don't care)
1. segment type (init request, end request, stdin, data, stdout, strerr etc...)
3. request id
4. request id (don't care, it is useful when the connection is shared for multiple request, not the case here)
5. data length
6. data length
7. padding length
8. void


## Racket implementation

The decoding incoming bytes part:

```racket
#lang racket

;; to store the input data
(struct request [segment-id stdin data params] #:mutable #:transparent)

(define (create-empty-request)
  (request #f (open-output-bytes) (open-output-bytes) (open-output-bytes)))

(define (decode-segment request in out)
  ;; don't care if read-bytes return eof
  (define header (read-bytes 8 in))
  (define segment-type (bytes-ref header 1))
  (define segment-id (+ (arithmetic-shift (bytes-ref header 2) 8)
                          (bytes-ref header 3)))
  ;; don't care if read-bytes return eof
  (define data-length (+ (arithmetic-shift (bytes-ref header 4) 8)
                         (bytes-ref header 5)))
  (define data (read-bytes data-length in))
  ;; consume the padding bytes
  (void (read-bytes (bytes-ref header 6) in))

  (printf "segment type: ~a\n" segment-type)
  (printf "id: ~a\n" segment-id)
  (printf "data length: ~a\n" data-length)
  (printf "~a\n" data)

  ;; segment-id = 0 is a special case where the web server and the fastcgi
  ;; process exchange information like n° of maximum connection so... we don't
  ;; care.
  (when (= 0 segment-id)
    (raise "unimplemented"))

  (printf "~a\n" request)

  (case segment-type
    ;; fcgi beginrequest
    ((1) (set-request-segment-id! request segment-id))
    ;; fcgi params
    ((4) (display data (request-params request)))
    ;; fcgi stdin
    ((5) (if (= 0 data-length) ; Not sure if it's the rigth way but use that to
                               ; know if the webserver input is over.
             (respond request out)
             (display data (request-stdin request))))
    ;; fcgi data
    ((8) (display data (request-data request)))
    ;; fcgi get values
    ;; fcgi abort request
    ((2 9) (raise "unimplemented"))
    (else (raise "undocumented type"))))
```

The response:

```racket
(define (build-header type id data-length padding-length)
  (bytes 1 type
         (arithmetic-shift id -8) (modulo id 256)
         (arithmetic-shift data-length -8) (modulo data-length 256)
         padding-length 0))

(define (respond request out)
  ;; header of the stdout
  (write-bytes (build-header 6 (request-segment-id request) 64 0) out)
  ;; the stdout data
  (write-bytes
   #"Content-type: text/html\r\n\r\n<html><body>hello fcgi</body></html> "
   out)
  ;; an empty stdout data to indicate we have finish the stdout stream
  (write-bytes (build-header 6 (request-segment-id request) 0 0) out)
  ;; the end request type
  (write-bytes (build-header 3 (request-segment-id request) 8 0) out)
  (write-bytes (bytes 0 0 0 0 0 0 0 0) out)
  (close-output-port out))
```

The server:

```racket
(module+ main
  (require racket/tcp)
  (define server (tcp-listen 1025))
  (let loop-main ()
    (let-values ([(in out) (tcp-accept server)]
                 [(request) (create-empty-request)])
      (let loop ()
        (if (port-closed? out)
            ;; the end of the request
            (close-input-port in)
             (begin
               (decode-segment request in out)
               (loop))))
      )
    (loop-main)))
```

Nginx configuration:

```nginx
location ~ \.rkt$ {
    fastcgi_pass 127.0.0.1:1025;
    include fastcgi.conf; # this add several parameters to be pass
                          # to the fastcgi process like http method.
}
```

go to _http://localhost/anything.rkt_ that display "hello fcgi"

## Display the HTTP headers

First of all we need to extract the parameters form the request-params field, it
is [name, value pair](http://www.fastcgi.com/devkit/doc/fcgi-spec.html#S3.4)
with their respective length before.

```racket
(define (decode-params in)
  (define (decode-param-length in)
    (define b3 (read-byte in))
    (cond [(equal? b3 eof) eof]
          [(> b3 #x7f)
           (let ([others (read-bytes 3 in)])
             (+
              (arithmetic-shift (bitwise-and b3 #x7f) 24)
              (arithmetic-shift (bytes-ref others 2) 16)
              (arithmetic-shift (bytes-ref others 1) 8)
              (bytes-ref others 0)))]
          [else b3]))
  (let loop ([result empty])
    (let ([length0 (decode-param-length in)])
      (if (equal? eof length0)
          result
          (let ([length1 (decode-param-length in)])
            (loop
             (cons
              (cons (read-bytes length0 in)
                    (read-bytes length1 in))
              result)))))))
```

Apply this decoder and present them, also do convenience functions.

```racket
(define (fcgi-end-request id out)
  (write-bytes (build-header 3 id 8 0) out)
  (write-bytes (bytes 0 0 0 0 0 0 0 0) out)
  (close-output-port out))
 
(define (write-fcgi-stdout id data out [close #f])
  (define data-length (bytes-length data))
  (define padding-length (if (= 0 (modulo data-length 8)) 0 (- 8 (modulo data-length 8))))
  (write-bytes (build-header 6 id data-length padding-length) out)
  (write-bytes data out)
  (when (not (= 0 padding-length))
    (write-bytes (make-bytes padding-length) out))
  (when close
    (write-bytes (build-header 6 id 0 0) out)))

(define (respond request out)
  ;; get the data from request
  (define params (decode-params
                  (open-input-bytes (let ([port (request-params request)])
                                      (close-output-port port)
                                      (get-output-bytes port)))))
  (define data (open-output-bytes))
  (write-bytes #"Content-type: text/html\r\n\r\n<html><body>" data)
  (write-bytes #"<table>" data)
  (for ([param params])
    (write-bytes #"<tr><td>" data)
    (write-bytes (car param) data)
    (write-bytes #"</td><td>" data)
    (write-bytes (cdr param) data)
    (write-bytes #"</td></tr>" data))
  (write-bytes #"</table>" data)
  (write-bytes #"</body></html>" data)
  (close-output-port data)

  (write-fcgi-stdout (request-segment-id request)
                     (get-output-bytes data)
                     out
                     #t)
  ;; the end request type
  (fcgi-end-request (request-segment-id request) out))
```

## Performance expectation

To have an idea where the n° of requests per seconds I used <code>ab -c 25 -n 10000</code> on several configurations:

* racket web/server (a web server written in pure racket): 1300
* nginx + chicken fastcgi binding: 10000
* nginx + php fpm (5 worker thread seems to be the optimal on my 2 core cpu): 7700
* nginx: 18000
* my stuff: 300

Wait what 300, something is wrong obviously, furthermore <code>ab</code> get stuck most of
the time at the last 1000 request. After suspecting the gc I find that I didn't
read the doc for
[tcp-listen](http://docs.racket-lang.org/reference/tcp.html?q=tcp-liste#%28def._%28%28lib._racket%2Ftcp..rkt%29._tcp-listen%29%29)
and changed the max-allow-wait to something like 1024. And get then 2500
request/second, even more by removing printf to 6500 r/s.

[The whole code](/code/fastcgi.rkt)

## Adding threads

The server can still handle one request at a time waiting for the first to
finish. Using the green thread of racket will enable to execute request
concurrently.

The change to the code is straightforward just create a new thread for **every**
incoming request.

```racket
(module+ main
  (require racket/tcp)
  (define server (tcp-listen 1025 1024 #t))
  (let loop-main ()
    (let-values ([(in out) (tcp-accept server)]
                 [(request) (create-empty-request)])
      (thread
       (lambda ()
         (let loop ()
           ;; similate work
           (sleep sleeping-time)
           (if (port-closed? out)
               ;; the end of the request
               (close-input-port in)
               (begin
                 (decode-segment request in out)
                 (loop))))
         ))
      )
    (loop-main)))
```

To show the difference from before lets simulate some work with the
sleeping-time variable and use <code>ab -c 100 -n 10000</code> to run our experiments.

From the previous **non** threaded code:

* <var>sleeping-time</var>=0.0001 -> 1600 request/s
* <var>sleeping-time</var>=0.001 -> 196 request/s

With threaded code:

* <var>sleeping-time</var>=0.01 -> 1900 request/s

Even for heavier work the threaded code is faster.

### A round robin strategy

Instead of create a new thread and a new request every time we have an incoming
request, create a bunch of thread and select them through a round robin approach.

```racket
(module+ main
  (require racket/tcp)
  (define server (tcp-listen 1025 1024 #t))

  (define max-thread 100)
  (define round-robin
    (let ([robin 0])
      (lambda ()
        (define rob (modulo (add1 robin) max-thread))
        (set! robin rob)
        rob)))


  (define (create-thread request)
  (define (reset-request! request)
    (set-request-segment-id! request #f)
    (set-request-stdin! request (open-output-bytes))
    (set-request-data! request (open-output-bytes))
    (set-request-params! request (open-output-bytes)))

  (thread
     (lambda ()
       (let main-loop ()
         (define in (thread-receive))
         (define out (thread-receive))
         (reset-request! request)
         (let loop ()
           (sleep 0.0001)
           (if (port-closed? out)
               ;; the end of the request
               (close-input-port in)
               (begin
                 (decode-segment request in out)
                 (loop))))
         (main-loop)))))

  (define thread-vec (for/vector ([i (range max-thread)])
                       (create-thread (create-empty-request))))

  (let loop-main ()
    (let-values ([(in out) (tcp-accept server)]
                 #;[(request) (create-empty-request)]
                 [(rob) (round-robin)])

      (thread-send (vector-ref thread-vec rob) in)
      (thread-send (vector-ref thread-vec rob) out)
      )
    (loop-main)))
```

I have no idea which approach is better, if I increase the number of concurrent
connection in apache bench the round robin seems to do better, but this is maybe
just due to the fact that round robin set a fixed maximum number of threads.

[round robin code](/code/fastcgi-robin.rkt)

## Gambit implementation

Quickly do a gambit implementation and get 6800 request/second.

[gambit code](/code/fastcgi-gambit.scm)
