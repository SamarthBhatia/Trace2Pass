/* Trace2Pass benchmark harness: md4c
 * Workload: parse a synthetic markdown document N times via md_parse().
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "md4c.h"

static const char *doc =
    "# Heading 1\n\n"
    "Some *emphasised* and **strong** text with [a link](https://example.com).\n\n"
    "## Heading 2\n\n"
    "- item one\n- item two\n- item three\n\n"
    "```c\nint main(void){return 0;}\n```\n\n"
    "> A blockquote with multiple lines\n> continues here.\n\n"
    "Paragraph with `code span` and more text to parse.\n\n"
    "| col1 | col2 |\n|------|------|\n| a    | b    |\n| c    | d    |\n";

static int cb_enter_block(MD_BLOCKTYPE t, void *d, void *u) { (void)t;(void)d;(void)u; return 0; }
static int cb_leave_block(MD_BLOCKTYPE t, void *d, void *u) { (void)t;(void)d;(void)u; return 0; }
static int cb_enter_span(MD_SPANTYPE t, void *d, void *u)   { (void)t;(void)d;(void)u; return 0; }
static int cb_leave_span(MD_SPANTYPE t, void *d, void *u)   { (void)t;(void)d;(void)u; return 0; }
static int cb_text(MD_TEXTTYPE t, const MD_CHAR *p, MD_SIZE n, void *u) {
    (void)t;(void)p;(void)u; long *c = (long*)u; if (c)(*c)+=n; return 0;
}

int main(void) {
    MD_PARSER p = {0};
    p.abi_version = 0;
    p.flags = MD_DIALECT_GITHUB;
    p.enter_block = cb_enter_block;
    p.leave_block = cb_leave_block;
    p.enter_span = cb_enter_span;
    p.leave_span = cb_leave_span;
    p.text = cb_text;

    struct timespec s, e;
    clock_gettime(CLOCK_MONOTONIC, &s);
    long counter = 0;
    for (int i = 0; i < 5000; i++) {
        md_parse(doc, (MD_SIZE)strlen(doc), &p, &counter);
    }
    clock_gettime(CLOCK_MONOTONIC, &e);
    double ms = (e.tv_sec - s.tv_sec) * 1000.0 + (e.tv_nsec - s.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return counter > 0 ? 0 : 1;
}
