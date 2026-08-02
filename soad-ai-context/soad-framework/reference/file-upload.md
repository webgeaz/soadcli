# File Upload

The form must use `method="post"` and `enctype="multipart/form-data"` with an `<input type="file" name="X">`. SØAD then exposes **three** request parameters per file input:

- `X` → file content as `byte[]`
- `X_ft` → MIME type (e.g. `image/png`)
- `X_fn` → original filename

```html
<form action="{{ctxPath}}/t/upload/image/upload" method="post" enctype="multipart/form-data">
  <input type="file" name="photo" required>
  <button type="submit">Upload</button>
</form>
```

```python
from utils import render
from java.io import File
from com.google.common.io import Files

class Image(object):
    def upload(self, ctx):
        """POST"""                            # exact docstring — POST-only (mutating)
        request = ctx.getRequest()
        content = request.getParameter("photo")      # byte[]
        ftype   = request.getParameter("photo_ft")   # MIME type
        fname   = request.getParameter("photo_fn")   # original filename

        if not content:
            ctx.output["message"] = "Please select a file"
            ctx.go_to = render.as_view(ctx, "upload_status")
            return

        if ftype not in ["image/png", "image/jpeg"]:
            ctx.output["message"] = "Only PNG and JPEG allowed"
            ctx.go_to = render.as_view(ctx, "upload_status")
            return

        Files.write(content, File("/tmp/uploads/" + fname))
        ctx.output["message"] = "Uploaded: " + fname
        ctx.go_to = render.as_view(ctx, "upload_status")
```

Notes:
- Validate type (`_ft`) and size (`len(content)`) before saving.
- To store in the DB instead of disk, use a BLOB column (see models-and-sql.md): setting `resume` also populates `resume_fn`/`resume_ft`. Serve it back with `render.as_blob(ctx, content, ftype, fname, attachment=False)`.
