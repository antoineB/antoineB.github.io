(##include "~~lib/gambit#.scm")

(declare (block)
         (standard-bindings)
         (extended-bindings)
         (not safe))

(define-structure request segment-id stdin data params end)

(define (create-empty-request)
  (make-request #f (open-output-u8vector) (open-output-u8vector) (open-output-u8vector) #f))

(define (build-header type id data-length padding-length)
  (u8vector 1 type
            (arithmetic-shift id -8) (bitwise-and id 255)
            (arithmetic-shift data-length -8) (bitwise-and data-length 255)
            padding-length 0))

(define (fcgi-end-request request in-out)
  (write-subu8vector (build-header 3 (request-segment-id request) 8 0) 0 8 in-out)
  (write-subu8vector (u8vector 0 0 0 0 0 0 0 0) 0 8 in-out)
  (close-port in-out)
  (request-end-set! request #t))

(define (decode-params in)
  (let ([decode-param-length
         (lambda (in)
           (let* ((data (make-u8vector 4)))
             (cond [(= 0 (read-subu8vector data 0 1 in)) #!eof]
                   [(> (u8vector-ref data 0) #x7f)
                    (read-subu8vector data 1 3 in)
                    (+
                     (arithmetic-shift (bitwise-and (u8vector-ref data 0) #x7f) 24)
                     (arithmetic-shift (u8vector-ref data 3) 16)
                     (arithmetic-shift (u8vector-ref data 2) 8)
                     (u8vector-ref data 1))]
                   [else (u8vector-ref data 0)])))])
  (let loop ([result '()])
    (let ([length0 (decode-param-length in)])
      (if (eof-object? length0)
          result
          (let* ([length1 (decode-param-length in)]
                 [name (make-u8vector length0)]
                 [value (make-u8vector length1)])
            (read-subu8vector name 0 length0 in)
            (read-subu8vector value 0 length1 in)
            (loop
             (cons
              (cons name value)
              result))))))))

(define (decode-segment request in-out)
  ;; don't care if read-bytes return eof
  (let* ([header (make-u8vector 8)]
         [_ (read-subu8vector header 0 8 in-out)]
         [segment-type (u8vector-ref header 1)]
         [segment-id (+ (arithmetic-shift (u8vector-ref header 2) 8)
                        (u8vector-ref header 3))]
         [data-length (+ (arithmetic-shift (u8vector-ref header 4) 8)
                         (u8vector-ref header 5))]
         [data (make-u8vector data-length)])
    (read-subu8vector data 0 data-length in-out)
    (read-subu8vector (make-u8vector (u8vector-ref header 6)) 0 (u8vector-ref header 6) in-out)

    ;; segment-id = 0 is a special case where the web server and the fastcgi
    ;; process exchange information like n° of maximum connection so... we don't
    ;; care.
    (if (= 0 segment-id)
        (raise "unimplemented"))

    (case segment-type
      ;; fcgi beginrequest
      ((1) (request-segment-id-set! request segment-id))
      ;; fcgi params
      ((4) (write-subu8vector data 0 data-length (request-params request)))
      ;; fcgi stdin
      ((5) (if (= 0 data-length) ; Not sure if it's the rigth way but use that
                                 ; to know if the webserver input is over.
               (respond request in-out)
               (write-subu8vector data 0 data-length (request-stdin request))))
      ;; fcgi data
      ((8) (write-subu8vector data 0 data-length (request-data request)))
      ;; fcgi get values
      ;; fcgi abort request
      ((2 9) (raise "unimplemented"))
      (else (raise "undocumented type")))))

(define (write-fcgi-stdout id data in-out #!optional (close #f))
  (let* ([data-length (u8vector-length data)]
         [padding-length (if (= 0 (modulo data-length 8)) 0 (- 8 (modulo data-length 8)))])
    (write-subu8vector (build-header 6 id data-length padding-length) 0 8 in-out)
    (write-subu8vector data 0 data-length in-out)
    (if (not (= 0 padding-length))
        (write-subu8vector (make-u8vector padding-length) 0 padding-length in-out))
    (if close
        (write-subu8vector (build-header 6 id 0 0) 0 8 in-out))))



(define (write-str-byte str)
  (let ([vect (object->u8vector str)])
    (write-subu8vector
     vect
     0
     (u8vector-length vect))))

(define (respond request in-out)
  ;; get the data from request
  (write-fcgi-stdout
   (request-segment-id request)
   (with-output-to-u8vector
    '()
    (lambda ()
      (let ([params (decode-params (open-input-u8vector (let ([port (request-params request)])
                                                          (close-output-port port)
                                                          (get-output-u8vector port))))])
        (write-str-byte "Content-type: text/html\r\n\r\n<html><body>")
        (write-str-byte "<table>")
        (let loop ([params params])
          (if (not (eq? params '()))
              (begin
                (write-str-byte "<tr><td>")
                (write-subu8vector (caar params) 0 (u8vector-length (caar params)))
                (write-str-byte "</td><td>")
                (write-subu8vector (cdar params) 0 (u8vector-length (cdar params)))
                (write-str-byte "</td></tr>")
                (loop (cdr params)))))
        (write-str-byte "</table>")
        (write-str-byte "</body></html>"))))
   in-out
   #t)
  ;; the end request type
  (fcgi-end-request request in-out))


(define server
  (open-tcp-server
   (list server-address: "localhost"
         port-number: 1026
         backlog: 1024
         reuse-address: #t)))

(let loop ()
  (let* ([connection (read server)]
         [request (create-empty-request)]
         [th (make-thread
              (lambda ()
                (let inner-loop ()
                  (if (not (request-end request))
                      (begin
                        (decode-segment request connection)
                        (inner-loop))))))])
    (thread-start! th))
  (loop))
