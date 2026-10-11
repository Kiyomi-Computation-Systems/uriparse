;;; The program check-akku.sh runs inside a consumer project, with only the
;;; library path Akku's activate script sets. It reads one URI through each
;;; layer, the string one and the byte one, and prints what it read:
;;; `example.com /b`. (uri grammar) is imported for its own import of
;;; (byte-machine graph), the one byte-machine library the other two never load.
(import (rnrs)
        (uri easy)
        (uri collect)
        (uri components)
        (only (uri grammar) make-uri-scanner-machine))

(define host (uri-host (string->uri "https://Example.COM:8443/a?q=1")))

(define path
  (let ((result (uri-parse 'uri (string->utf8 "http://a/b"))))
    (unless (uri-parse-ok? result)
      (error 'consumer "the byte layer refused http://a/b"))
    (utf8->string (uri-components-path (uri-parse-components result)))))

(display host)
(display " ")
(display path)
(newline)
