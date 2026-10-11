#!r6rs
;;; (uri test raised): checks on what a thunk raises, shared by the lanes that
;;; grade a library's conditions (unit.easy and unit.easy-resolve).
;;;
;;; Product-independent, like (uri test ranged): the condition predicate and its
;;; accessors come from the caller, so this library imports only (rnrs) and the
;;; harness. One copy of the judgement means the lanes cannot drift apart in how
;;; strictly they read a raise.
(library (uri test raised)
  (export raised check-raised check-refuses)
  (import (rnrs) (only (uri test harness) check check-equal check-fail))

  ;; raised : (-> Any) -> (Option Any)
  ;; The object the thunk raised, or #f when it returned.
  (define (raised thunk)
    (guard (e (#t e)) (thunk) #f))

  ;; check-raised : String (-> Any) (Any -> Boolean) Symbol
  ;;                (Listof (List String (Any -> Any) Any)) -> Unspecified
  ;; The thunk must raise an object satisfying `kind?`, whose &who is `who`, and
  ;; which is NOT an assertion violation: bad input, not a caller's mistake.
  ;; Then each (name accessor expected) field is compared.
  (define (check-raised label thunk kind? who fields)
    (let ((c (raised thunk)))
      (if (and c (kind? c))
          (begin
            (check-equal (string-append label ": who")
                         (and (who-condition? c) (condition-who c)) who)
            (check (string-append label ": not an assertion") (not (assertion-violation? c)))
            (for-each
             (lambda (f)
               (check-equal (string-append label ": " (car f)) ((cadr f) c) (caddr f)))
             fields))
          (check-fail label "expected a raise that satisfies the predicate"))))

  ;; check-refuses : String (-> Any) Symbol -> Unspecified
  ;; An assertion violation whose &who is `who`: the public procedure, not
  ;; whichever R6RS primitive happened to trip over the bad argument first.
  (define (check-refuses label thunk who)
    (let ((c (raised thunk)))
      (check-equal (string-append label ": an assertion naming " (symbol->string who))
                   (and c (assertion-violation? c) (who-condition? c) (condition-who c))
                   who))))
