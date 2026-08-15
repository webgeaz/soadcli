# File Upload

The form must use `method="post"` and `enctype="multipart/form-data"` with an `<input type="file" name="X">`. SØAD then exposes **three** request parameters per file input:

- `X` → request-scoped `UploadedFile` object (NOT a `byte[]`)
- `X_ft` → MIME type (e.g. `image/png`)
- `X_fn` → original filename (e.g. `photo.png`)

```html
<form action="{{ctxPath}}/t/upload/image/upload" method="post" enctype="multipart/form-data">
  <input type="file" name="photo" required>
  <button type="submit">Upload</button>
</form>
```

```python
from utils import render
from java.io import File

class Image(object):
    def upload(self, ctx):
        """POST"""                            # exact docstring — POST-only (mutating)
        request = ctx.getRequest()
        uploaded_file = request.getParameter("photo")   # UploadedFile object
        ftype   = request.getParameter("photo_ft")      # MIME type
        fname   = request.getParameter("photo_fn")      # original filename

        if not uploaded_file or not fname:
            ctx.output["message"] = "Please select a file"
            ctx.go_to = render.as_view(ctx, "upload_status")
            return

        if ftype not in ["image/png", "image/jpeg"]:
            ctx.output["message"] = "Only PNG and JPEG allowed"
            ctx.go_to = render.as_view(ctx, "upload_status")
            return

        # Check size BEFORE consuming the stream
        if uploaded_file.getSize() > 5 * 1024 * 1024:
            ctx.output["message"] = "File too large (max 5MB)"
            ctx.go_to = render.as_view(ctx, "upload_status")
            return

        # Write to disk — use writeTo() (streams) for large files
        uploaded_file.writeTo(File("/tmp/uploads/" + fname))
        ctx.output["message"] = "Uploaded: " + fname
        ctx.go_to = render.as_view(ctx, "upload_status")
```

Notes:
- `UploadedFile` methods: `getFileName()`, `getContentType()`, `getSize()`, `getInputStream()`, `writeTo(destination)`, `getBytes()`.
- **Upload data is deleted automatically after the request finishes** — save/consume it inside the transaction. Do NOT defer file access.
- **Prefer streams / `writeTo()`** for large files. `getBytes()` loads the whole file into memory — only use after enforcing a small size limit.
- **Do NOT call `len(uploaded_file)` or `GuavaFiles.write(uploaded_file, ...)`** — it's an object, not `byte[]`. Use `getSize()` and `writeTo()`.
- `maxfileuploadsize` limits each file; `maxrequestuploadsize` limits the whole multipart request (defaults to file limit + 1 MiB); `fileuploadtempdir` selects the spool dir (default `${java.io.tmpdir}/soad-uploads`).
- To store in the DB instead of disk, use a BLOB column (see models-and-sql.md): setting `resume` also populates `resume_fn`/`resume_ft`. Serve it back with `render.as_blob(ctx, content, ftype, fname, attachment=False)`.
