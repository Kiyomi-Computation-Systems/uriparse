;;; RFC 3986 section 1.1.2 -- example URIs across eight schemes.
;;;
;;; DERIVED from test/vendor/rfc3986.txt by cmake/UriCorpus.cmake. Do not edit.
;;;
;;; Each row is (<section> <uri>). These carry no expected decomposition: the
;;; RFC gives them as illustrations, not as vectors, so what a lane may assert
;;; over them is that they parse -- never a component boundary the RFC never
;;; stated.
(uris
  ("1.1.2" "ftp://ftp.is.co.za/rfc/rfc1808.txt")
  ("1.1.2" "http://www.ietf.org/rfc/rfc2396.txt")
  ("1.1.2" "ldap://[2001:db8::7]/c=GB?objectClass?one")
  ("1.1.2" "mailto:John.Doe@example.com")
  ("1.1.2" "news:comp.infosystems.www.servers.unix")
  ("1.1.2" "tel:+1-816-555-1212")
  ("1.1.2" "telnet://192.0.2.16:80/")
  ("1.1.2" "urn:oasis:names:specification:docbook:dtd:xml:4.1.2")
)
