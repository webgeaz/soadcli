# Integrations

## JSON API

Return JSON with `render.as_json`. Pass an explicit object, or omit it to serialize `ctx.output`. Convert model lists with `.toMaps()`.

```python
from utils import render
from models import Product

class Api(object):
    def products(self, ctx):
        ctx.go_to = render.as_json(ctx, Product.findAll().toMaps())

    def create(self, ctx):
        """POST"""                            # exact docstring — POST-only
        r = ctx.getRequest()
        p = Product()
        p.set("name", r.getParameter("name"))
        p.saveIt()
        ctx.go_to = render.as_json(ctx, {"status": "ok", "id": p.get("id")})
```
URLs: `/t/api/products`, `/t/api/create`. For a single object: `render.as_json(ctx, {"status": "success", "user": {"id": 1}})`.

## AJAX (jQuery)

jQuery is bundled. Call a transaction action that returns JSON and update the page without reload.

```html
<button id="load">Load</button>
<ul id="list"></ul>
<script>
$("#load").on("click", function () {
  $.getJSON("{{ctxPath}}/t/api/products", function (data) {
    $("#list").empty();
    $.each(data, function (i, p) { $("#list").append("<li>" + p.name + "</li>"); });
  });
});
</script>
```
For POSTs, send `$.post("{{ctxPath}}/t/api/create", {name: "X"}, cb, "json")`.

## htmx

htmx is bundled — swap server-rendered HTML fragments without writing JS. The action returns an HTML fragment (often via `render.as_string` or a small `render.as_view` partial).

```html
<script src="https://unpkg.com/htmx.org@1.9.10"></script>

<button hx-get="{{ctxPath}}/t/app/todo/count" hx-target="#out" hx-swap="innerHTML">
  Refresh count
</button>
<div id="out"></div>
```
```python
from utils import render
from models import Todo as TodoModel   # alias if this method lives on class Todo

class Todo(object):
    def count(self, ctx):              # GET fragment for htmx
        n = TodoModel.where("done = ?", False).size()  # BIT: use Python bool
        ctx.go_to = render.as_string(ctx, "<span>%d open</span>" % n)
```
Use `hx-post` + `hx-target` for form submissions that replace a region with the response fragment. Return just the fragment, not a full page (leave off full `<!DOCTYPE html>` wrappers for partials).

## DataTables

DataTables is bundled. Render a normal table, then initialize it for client-side paging/search/sort. Good when the row count is modest.

```html
<link href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css" rel="stylesheet">
<table id="grid" class="table">
  <thead><tr><th>Name</th><th>Email</th></tr></thead>
  <tbody>
    {{#each contacts}}
    <tr><td>{{name}}</td><td>{{email}}</td></tr>
    {{/each}}
  </tbody>
</table>
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
<script>$(function () { $("#grid").DataTable(); });</script>
```
For very large datasets use DataTables server-side mode, pointing `ajax` at a transaction that returns JSON in the DataTables response shape.

## Excel export (Apache POI)

Apache POI is bundled — build a workbook and stream it with `render.as_blob` (or save with `render.as_file`).

```python
from utils import render
from models import Sale
from org.apache.poi.xssf.usermodel import XSSFWorkbook
from java.io import ByteArrayOutputStream

class Report(object):
    def export(self, ctx):
        wb = XSSFWorkbook()
        sheet = wb.createSheet("Sales")
        header = sheet.createRow(0)
        header.createCell(0).setCellValue("Product")
        header.createCell(1).setCellValue("Amount")

        rows = Sale.findAll()
        i = 1
        for s in rows:
            row = sheet.createRow(i)
            row.createCell(0).setCellValue(s.get("product"))
            row.createCell(1).setCellValue(float(s.get("amount")))
            i += 1

        out = ByteArrayOutputStream()
        wb.write(out)
        wb.close()
        ctx.go_to = render.as_blob(
            ctx, out.toByteArray(),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "sales.xlsx", attachment=True)
```
Use `XSSFWorkbook` for `.xlsx`. Reading uploaded Excel works the same way via POI on the uploaded `byte[]`.
