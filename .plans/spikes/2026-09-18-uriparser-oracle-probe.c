/* Probe: can uriparser 1.0.2 serve as the differential oracle, and how does it
 * signal ABSENT versus PRESENT-AND-EMPTY?
 *
 * Decision 0008 rests on that distinction and the API docs do not state it.
 * Run:  cc -I/opt/homebrew/include -L/opt/homebrew/lib -luriparser \
 *          -o probe 2026-09-18-uriparser-oracle-probe.c && ./probe
 *
 * WHAT IT FOUND (2026-09-18, uriparser 1.0.2 via Homebrew, BSD-3-Clause):
 *
 * 1. THE CONVENTION IS USABLE. Absent is `first == afterLast == NULL`;
 *    present-and-empty is `first == afterLast`, both non-NULL. Consistent
 *    across scheme, userInfo, host, port, query and fragment. So the
 *    differential CAN check decision 0008's distinction.
 *
 * 2. BUT AN EMPTY RANGE'S POSITION IS NOT ALWAYS REAL. Empty userInfo, port,
 *    query and fragment point into the input (`http://a/b?` gives query at 11,
 *    which is correct). Empty HOST and empty PATH SEGMENTS point at a static
 *    sentinel instead: `http:///b` reported host at offset 266872 of a 9-byte
 *    string, and `http://a/` reported its one empty segment at 266944.
 *
 *    => THE SHIM NEVER SUBTRACTS OR DEREFERENCES AN EMPTY RANGE. It reports
 *       EMPTY as a value distinct from both ABSENT and [from,to). The
 *       comparator then compares absent/absent, empty/empty (no position),
 *       and [from,to)/[from,to).
 *
 *    This is the SAME rule our own machine needs for its own reasons -- see
 *    .plans/spikes/2026-09-18-eof-verdict-and-empty-span.sps and design §3.5
 *    item 3, where an empty span closing at `parser-finish!` reports (0 0)
 *    rather than (1 1). Two independent implementations, one rule: an empty
 *    component carries emptiness, never a position.
 *
 * 3. THE PATH CANNOT BE COLLAPSED BY POINTER ARITHMETIC. Taking
 *    pathHead->first .. pathTail->afterLast gives garbage whenever the first
 *    or last segment is empty -- which is every path ending in "/" and every
 *    path containing "//". `http://a/b/` collapsed to [9,266922).
 *
 *    => The shim reconstructs the path as TEXT: join the segments with "/",
 *       prefixed by "/" iff (host present && pathHead != NULL) || absolutePath.
 *       An empty segment contributes nothing and is never dereferenced.
 *       Verified lossless on "http://a/", "http://a//b", "http://a/b/",
 *       "http://a", "foo:/bar", "b/c" and "/".
 *
 * 4. `absolutePath` IS NOT "the path is absolute". Uri.h: "Absolute path flag,
 *    distincting \"a\" and \"/a\"; always URI_FALSE for URIs with host". So
 *    `http://a/b` reports absolutePath=FALSE even though its path is "/b".
 *    pathHead == NULL does NOT mean the path is empty either: "/" reports
 *    pathHead=NULL with absolutePath=TRUE, and its path is "/".
 *
 * 5. URIPARSER HAS NO MODE -- it always parses a URI-reference. `a:b` comes
 *    back as scheme "a" + path "b"; `b/c` as path-noscheme. So the differential
 *    is valid against OUR MODE 3 only (decision 0004); modes 1 and 2 need a
 *    pre-filter or no comparison at all.
 *
 * 6. ERRATUM 5428 IS REFUTED BY A SECOND IMPLEMENTATION. "/" parses cleanly
 *    (absolutePath=TRUE, no segments), as the ABNF says it must --
 *    `path-absolute = "/" [ segment-nz *( "/" segment ) ]` makes everything
 *    after the slash optional.
 */

#include <stdio.h>
#include <string.h>
#include <uriparser/Uri.h>

static void show(const char *label, const UriTextRangeA *r, const char *base) {
    printf("    %-9s ", label);
    if (r->first == NULL && r->afterLast == NULL) { printf("ABSENT (both NULL)\n"); return; }
    if (r->first == NULL || r->afterLast == NULL) {
        printf("HALF-NULL first=%p afterLast=%p\n", (void *)r->first, (void *)r->afterLast);
        return;
    }
    {
        long from = (long)(r->first - base), to = (long)(r->afterLast - base);
        if (from == to) printf("EMPTY  first==afterLast, offset %ld\n", from);
        else printf("[%ld,%ld) = \"%.*s\"\n", from, to, (int)(to - from), r->first);
    }
}

static void show_path(const UriUriA *u, const char *base) {
    const UriPathSegmentA *s = u->pathHead;
    int n = 0;
    printf("    %-9s absolutePath=%s", "path", u->absolutePath ? "TRUE" : "FALSE");
    if (s == NULL) { printf("  pathHead=NULL (no segments)\n"); return; }
    printf("\n");
    for (; s != NULL; s = s->next, n++) {
        char lbl[24];
        snprintf(lbl, sizeof lbl, "  seg[%d]", n);
        show(lbl, &s->text, base);
    }
    if (u->pathHead && u->pathTail)
        printf("    %-9s collapsed span = [%ld,%ld)\n", "",
               (long)(u->pathHead->text.first - base),
               (long)(u->pathTail->text.afterLast - base));
}

static void probe(const char *text) {
    UriUriA uri;
    const char *errorPos = NULL;
    int rc = uriParseSingleUriA(&uri, text, &errorPos);
    printf("== \"%s\"\n", text);
    if (rc != URI_SUCCESS) {
        printf("    PARSE FAILED rc=%d at offset %ld\n\n",
               rc, errorPos ? (long)(errorPos - text) : -1L);
        return;
    }
    show("scheme",   &uri.scheme,   text);
    show("userInfo", &uri.userInfo, text);
    show("host",     &uri.hostText, text);
    show("port",     &uri.portText, text);
    show_path(&uri, text);
    show("query",    &uri.query,    text);
    show("fragment", &uri.fragment, text);
    printf("\n");
    uriFreeUriMembersA(&uri);
}

int main(void) {
    const char *cases[] = {
        "http://a/",      /* path is "/" with a host */
        "http://a//b",    /* empty FIRST segment */
        "http://a/b/",    /* empty LAST segment (trailing slash) */
        "foo:/bar",       /* absolutePath, no host */
        "./a",            /* relative, dot segment */
        "a:b",            /* scheme or first segment? uriparser has no mode */
        "/",              /* erratum 5428 */
        NULL
    };
    int i;
    for (i = 0; cases[i] != NULL; i++) probe(cases[i]);
    return 0;
}
