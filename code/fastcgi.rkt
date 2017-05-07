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

  ;; (printf "segment type: ~a\n" segment-type)
  ;; (printf "id: ~a\n" segment-id)
  ;; (printf "data length: ~a\n" data-length)
  ;; (printf "~a\n" data)

  ;; segment-id = 0 is a special case where the web server and the fastcgi
  ;; process exchange information like n° of maximum connection so... we don't
  ;; care.
  (when (= 0 segment-id)
    (raise "unimplemented"))

  ;; (printf "~a\n" request)

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







(define (end-of-request id)
  (bytes
   ;; header
   1 3
   (arithmetic-shift id -8) (bitwise-bit-field id 0 8)
   0 8
   0
   0
   ;; the data ; what the status should be?
   0 0 0 0 0 0 0 0
   ))

(define (build-header type id data-length padding-length)
  (bytes 1 type
         (arithmetic-shift id -8) (modulo id 256)
         (arithmetic-shift data-length -8) (modulo data-length 256)
         padding-length 0))

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


(module+ main
  (require racket/tcp)
  (define server (tcp-listen 1025 1024 #t))
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
