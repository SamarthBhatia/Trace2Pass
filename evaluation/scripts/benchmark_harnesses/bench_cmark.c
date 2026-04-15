/* Trace2Pass benchmark harness: cmark (Markdown parsing + rendering) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <cmark.h>

static const char *markdown =
    "# Heading 1\n\n"
    "This is a paragraph with **bold**, *italic*, and `code` formatting.\n\n"
    "## Heading 2\n\n"
    "- Item 1\n"
    "- Item 2\n"
    "  - Nested item\n"
    "- Item 3\n\n"
    "### Heading 3\n\n"
    "1. First ordered item\n"
    "2. Second ordered item\n"
    "3. Third ordered item\n\n"
    "> This is a blockquote with some text that spans\n"
    "> multiple lines and contains **bold** text.\n\n"
    "```\n"
    "int main(void) {\n"
    "    return 0;\n"
    "}\n"
    "```\n\n"
    "Here is a [link](https://example.com) and an image reference.\n\n"
    "| Column 1 | Column 2 | Column 3 |\n"
    "|----------|----------|----------|\n"
    "| Cell 1   | Cell 2   | Cell 3   |\n"
    "| Cell 4   | Cell 5   | Cell 6   |\n\n"
    "---\n\n"
    "Final paragraph with some closing remarks.\n";

int main(void) {
    size_t md_len = strlen(markdown);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (int iter = 0; iter < 10000; iter++) {
        char *html = cmark_markdown_to_html(markdown, md_len, CMARK_OPT_DEFAULT);
        if (!html) return 1;
        /* Use output to prevent optimization */
        if (html[0] != '<') { free(html); return 1; }
        free(html);
    }

    /* Also test the node-based API */
    for (int iter = 0; iter < 5000; iter++) {
        cmark_node *doc = cmark_parse_document(markdown, md_len, CMARK_OPT_DEFAULT);
        if (!doc) return 1;
        char *xml = cmark_render_xml(doc, CMARK_OPT_DEFAULT);
        if (!xml) { cmark_node_free(doc); return 1; }
        free(xml);
        char *man = cmark_render_man(doc, CMARK_OPT_DEFAULT, 72);
        if (!man) { cmark_node_free(doc); return 1; }
        free(man);
        cmark_node_free(doc);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    printf("%.1f\n", ms);
    return 0;
}
