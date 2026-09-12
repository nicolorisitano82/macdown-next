/*
 *  Tools/commonmark_probe.c — un documento reso come lo rende l'app.
 *
 *  Markdown sullo standard input, HTML sullo standard output, con le
 *  estensioni che MPDocument accende. Serve a passare a hoedown gli esempi
 *  della specifica CommonMark e contare quanti tornano come dovrebbero;
 *  vive qui e non nei test perché non è una promessa, è una misura.
 *
 *      clang -O2 -I Dependency/hoedown/src -o probe \
 *          Tools/commonmark_probe.c Dependency/hoedown/src/*.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "document.h"
#include "html.h"


int main(int argc, char **argv)
{
    /* Le stesse di MPDocument con ogni interruttore acceso. --xhtml chiude
     * i tag vuoti come li chiude la specifica, che è il modo generoso di
     * contare. */
    unsigned int extensions = HOEDOWN_EXT_AUTOLINK | HOEDOWN_EXT_FENCED_CODE
        | HOEDOWN_EXT_FOOTNOTES | HOEDOWN_EXT_NO_INTRA_EMPHASIS
        | HOEDOWN_EXT_STRIKETHROUGH | HOEDOWN_EXT_TABLES
        | HOEDOWN_EXT_SPACE_HEADERS;
    unsigned int html = 0;
    for (int i = 1; i < argc; i++)
    {
        if (strcmp(argv[i], "--xhtml") == 0)
            html |= HOEDOWN_HTML_USE_XHTML;
        else if (strcmp(argv[i], "--plain") == 0)
            extensions = HOEDOWN_EXT_SPACE_HEADERS;
    }

    char *input = NULL;
    size_t size = 0, used = 0;
    int c;
    while ((c = getchar()) != EOF)
    {
        if (used + 1 >= size)
        {
            size = size ? size * 2 : 4096;
            input = realloc(input, size);
            if (!input)
                return 1;
        }
        input[used++] = (char)c;
    }

    hoedown_renderer *renderer = hoedown_html_renderer_new(html, 0);
    hoedown_document *document = hoedown_document_new(renderer, extensions, 16);
    hoedown_buffer *out = hoedown_buffer_new(64);
    hoedown_document_render(document, out, (const uint8_t *)(input ?: ""), used);
    fwrite(out->data, 1, out->size, stdout);

    hoedown_buffer_free(out);
    hoedown_document_free(document);
    hoedown_html_renderer_free(renderer);
    free(input);
    return 0;
}
