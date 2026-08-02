# Render, Logging & Utilities

## Render methods (`from utils import render`)

**First: you often don't need `render` at all.** If a method leaves `ctx.go_to` unset, the framework auto-renders the default view `_{code}/{code}.html`. Only use the methods below to return something *other* than the default view. Assign the result to `ctx.go_to`.

```python
render.as_view(ctx, view, group=None, code=None)   # Handlebars HTML (most common)
render.as_json(ctx, obj=None)                        # JSON; defaults to ctx.output
render.as_html(ctx, code=None)                       # raw HTML file, no Handlebars
render.as_string(ctx, text)                          # raw string/HTML
render.as_file(ctx, file, content_type, filename=None, attachment=True)   # download/inline
render.as_blob(ctx, data, content_type, filename=None, attachment=True)   # in-memory binary
render.as_pdf(ctx, view, group=None, code=None, filename=None, attachment=False)  # HTML->PDF
```

- `as_view(ctx, "home")` renders `_home/home.html` in the current group. Pass `group=`/`code=` to render a view that belongs to another transaction.
- **`render.as_view(...)` returns a callable.** Assigning it to `ctx.go_to` lets the framework invoke it. To get the rendered HTML **as a string** (for email bodies or PDF input), call it yourself with a trailing `()`:
  ```python
  html = render.as_view(ctx, "invoice")()   # note the extra ()
  ```
- `as_json` with a model list: `render.as_json(ctx, Tb_user.findAll().toMaps())`.
- `as_file` takes a Java `File` or path string; `attachment=False` displays inline (e.g. show an image). `as_blob` is for binary already in memory (e.g. a DB BLOB column).
- `as_pdf` needs well-formed XHTML in the template (openpdf-backed HTML→PDF).

## Logging (`from sufia.util import Log`)

```python
from sufia.util import Log

Log.info(ctx, "message")
Log.debug(ctx, "params: %s" % ctx.getAllParameters())
Log.warn(ctx, "warning")
Log.error(ctx, "failed: %s" % str(e))          # optional 3rd arg: the exception object
Log.print(ctx, "same as info")
Log.trace(ctx, "very detailed")
```
Prefer `Log.*` over `print()` — in containers `print()` may not reach the IDE log. Use `%` formatting (never f-strings) in log strings. Common pattern:
```python
try:
    ...
except Exception as e:
    Log.error(ctx, "Error: %s" % str(e))
    raise       # bare raise — keeps the original traceback (Jython/Python 2)
    # raise e   # WRONG: re-raises a new frame and loses the original traceback
```
Re-raise so the framework rolls back the DB transaction. For class-specific loggers you can also use SLF4J directly: `from org.slf4j import LoggerFactory`.

## Email (`from utils import mailer`)

```python
mailer.send(sender, receiver, subject, content,
            cc=[], bcc=[], html=False, attachment=[], reply_to=None)
```
- `content` is text, or HTML when `html=True`. `attachment` is a list of file paths.
- Build an HTML body from a view: `body = render.as_view(ctx, "welcome_email")()` (trailing `()`), then `mailer.send(..., body, html=True)`.

## PDF (`from utils import pdf`)

```python
from utils import pdf, render
html = render.as_view(ctx, "invoice")()        # XHTML string
pdf.generate(html, "/tmp/invoice.pdf")          # or pass outstream=
```
To stream a generated PDF to the browser instead of saving, use `render.as_pdf(ctx, "invoice", filename="invoice.pdf", attachment=True)`.

## Bundled Java helpers

- File IO: `from com.google.common.io import Files` → `Files.write(bytes, File(path))`, `Files.toString(file, "UTF-8")`.
- Base64: `from com.google.common.io import BaseEncoding` → `BaseEncoding.base64().encode(...)` / `.decode(...)`.
- Stream copy: `from com.google.common.io import ByteStreams` → `ByteStreams.copy(in, out)`.
- Import the Java classes directly; do NOT use pip. Need something else? The developer drops a JAR into `/webapp/WEB-INF/lib/`.

### Bundled JARs (use these when relevant)
- **guava-33.4.0-jre** — collections, caching, I/O, string utils (`com.google.common.*`)
- **commons-io-2.15.1** — file/stream utilities (`org.apache.commons.io.*`)
- **commons-lang3-3.14.0** — core lang utilities (`org.apache.commons.lang3.*`)
- **commons-text-1.11.0** — text processing/manipulation (`org.apache.commons.text.*`)
- **poi-5.4.0** — Apache POI for Office docs: Excel, Word, PowerPoint (`org.apache.poi.*`)
- **openpdf-2.0.3** — PDF generation/manipulation (backs the `utils.pdf` / `render.as_pdf` wrappers)
