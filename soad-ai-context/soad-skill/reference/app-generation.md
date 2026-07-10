# Generating a Complete Application

When asked to generate an app or feature, **always produce all of these, labeled with their file paths, in this order**:

1. **SQL** — local CLI: write `db/migrations/NNN_create_{code}.sql` (see models-and-sql.md). Web IDE / paste: labeled SQL block only (no fake migration path). Tell the user to run it in the IDE then Introspect.
2. The **transaction `.py` file** — path depends on mode (table below).
3. **The HTML views** — default + any extra views; path depends on mode.

**Paths by mode (do not mix):**

| Mode | SQL | Transaction | Views |
|---|---|---|---|
| **Local CLI project** | `db/migrations/NNN_....sql` file on disk | `src/{group}/{code}/{code}.py` | `src/{group}/{code}/_{code}/{code}.html` (+ extras) |
| **Web IDE / paste** | Labeled SQL block in chat | `{group}/{code}.py` | `_{code}/{code}.html` (+ extras) |

**In a local CLI project** (see SKILL.md), don't emit paste blocks for code — run `soad create <group>/<code>` yourself, write into the pulled `src/...` files, write the migration under `db/migrations/`, and run `soad push`. The user still runs SQL + Introspect in the IDE (the CLI doesn't apply DDL). **In web-IDE/paste mode**, output each artifact as a labeled block (SQL + `.py` + views) using the web-IDE paths above. Golden template labels below use web-IDE paths for readability.

Rules:
- One transaction class per logical entity; put all of its CRUD actions as methods on it. Don't split CRUD across files unless asked.
- **On any model name clash, alias the model** (`from models import Todo as TodoModel`). Applies to own class **and** imported transactions with the same name. Keep transaction names real for routing/inheritance.
- **Prefer the default view.** The `view()` action should leave `ctx.go_to` unset and let the framework auto-render `_{code}/{code}.html`. Add extra `.html` views (rendered with `render.as_view(ctx, "name")`) only for additional screens like a separate form.
- HTML views are **full standalone pages** (`<!DOCTYPE html>` … `</html>`), since default is no layout. Link Bootstrap from CDN.
- Reads are GET (no special docstring). **create, update, delete are POST** — method docstring must be exactly `"""POST"""` (the word `POST` alone; nothing else). Do not invent `@post` or comments. Then PRG-redirect with **`ctx.go_to = ctx.ctxPath + "/t/..."`** (always include `ctx.ctxPath`).
- **Primary key: default to `id INT PRIMARY KEY AUTO_INCREMENT`.** In Python: never set `id`; always `saveIt()` for insert and update. Use UUID (`VARCHAR(36)` + generate id + `insert()`/`saveIt()`) only if the user asks — and keep SQL and Python consistent (see models-and-sql.md).
- **Timestamps on new tables: `created_date` / `updated_date`.** Set both on insert; set `updated_date` on every update. Do not use `created_at`/`updated_at` for new tables.
- **Table names:** bare name matching the code is fine for simple apps (`todo`). Prefix by group only for multi-module apps (`hr_employee`) — see models-and-sql.md.
- A single `save` action handles both insert (no id / empty hidden field) and update (id present). With auto-increment: `findById(id)` accepts the request string as-is (no `int()` cast); use `Model.findById(id) if id else Model()` — empty string means create. Always `saveIt()`.
- **Checkboxes / BIT:** `obj.set("done", r.getParameter("done") == "on")` (unchecked posts nothing → False). Query with Python booleans: `where("done = ?", False)`.
- For the edit form, either reuse the list view via `self.view(ctx)` or use a separate `form` view — both are fine (see views.md). Pick one and stay consistent within the app.
- Pass success/error messages via the redirect URL query param (e.g. `?msg=saved`) and show them in the view. This is the default — SØAD has **no built-in flash scope**. Only implement a real flash mechanism if the user asks (see end of file). Do NOT invent one otherwise.
- Delete is a POST form with a JS confirm, never a bare link (so refresh/crawlers can't trigger it).
- List screens: a plain Bootstrap table is fine; use DataTables only if the user wants sort/search (see integrations.md).

## Golden Template — Todo CRUD (group `app`, code `todo`)

The list is the **default view** (`_todo/todo.html`, auto-rendered, no render call). The form is an **extra view** (`_todo/form.html`, rendered explicitly).

**1. SQL** — `db/migrations/001_create_todo.sql` (run in the IDE, then Introspect)
```sql
CREATE TABLE todo (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    done BIT DEFAULT 0,
    created_date DATETIME,
    updated_date DATETIME
);
```
→ auto-generates model class `Todo`.

**2. `app/todo.py`** (CLI path: `src/app/todo/todo.py`)
```python
from utils import render
from models import Todo as TodoModel           # alias: model name == transaction class
from java.time import LocalDateTime

class Todo(object):
    def view(self, ctx):                       # GET — list (default view); no POST docstring
        ctx.output["todos"] = TodoModel.findAll().orderBy("created_date DESC")
        ctx.output["msg"] = ctx.getRequest().getParameter("msg")
        # ctx.go_to unset => auto-renders _todo/todo.html

    def form(self, ctx):                       # GET — add/edit form (extra view)
        id = ctx.getRequest().getParameter("id")
        if id:
            ctx.output["todo"] = TodoModel.findById(id)
        ctx.go_to = render.as_view(ctx, "form")    # non-default view => explicit

    def save(self, ctx):                       # POST — insert or update (auto-increment id)
        """POST"""                             # exact docstring — POST-only
        r = ctx.getRequest()
        id = r.getParameter("id")              # "" from empty hidden field => create
        # findById accepts str or int — no int(id); auto-increment: never set("id", ...)
        todo = TodoModel.findById(id) if id else TodoModel()
        todo.set("title", r.getParameter("title"))
        todo.set("done", r.getParameter("done") == "on")  # BIT; unchecked => False
        if not id:
            todo.set("created_date", LocalDateTime.now())
        todo.set("updated_date", LocalDateTime.now())
        todo.saveIt()                          # always saveIt() for auto-increment
        ctx.go_to = ctx.ctxPath + "/t/app/todo?msg=saved"

    def delete(self, ctx):                     # POST — delete
        """POST"""
        todo = TodoModel.findById(ctx.getRequest().getParameter("id"))
        if todo:
            todo.delete()
        ctx.go_to = ctx.ctxPath + "/t/app/todo?msg=deleted"
```

**3. `_todo/todo.html`** (default view — filename matches the code)
```html
<!DOCTYPE html>
<html>
<head>
  <title>Todos</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
  <div class="container py-4">
    <h1>Todos</h1>
    {{#if msg}}<div class="alert alert-success">{{msg}}</div>{{/if}}
    <a href="{{ctxPath}}/t/app/todo/form" class="btn btn-primary mb-3">Add Todo</a>
    {{#if todos}}
    <table class="table">
      <thead><tr><th>Title</th><th>Done</th><th></th></tr></thead>
      <tbody>
        {{#each todos}}
        <tr>
          <td>{{title}}</td>
          <td>{{#if done}}Yes{{else}}No{{/if}}</td>
          <td>
            <a href="{{../ctxPath}}/t/app/todo/form?id={{id}}" class="btn btn-sm btn-secondary">Edit</a>
            <form action="{{../ctxPath}}/t/app/todo/delete" method="post" class="d-inline"
                  onsubmit="return confirm('Delete this todo?')">
              <input type="hidden" name="id" value="{{id}}">
              <button class="btn btn-sm btn-danger">Delete</button>
            </form>
          </td>
        </tr>
        {{/each}}
      </tbody>
    </table>
    {{else}}
    <div class="alert alert-info">No todos yet.</div>
    {{/if}}
  </div>
</body>
</html>
```

**4. `_todo/form.html`**
```html
<!DOCTYPE html>
<html>
<head>
  <title>{{#if todo}}Edit{{else}}Add{{/if}} Todo</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
  <div class="container py-4">
    <h1>{{#if todo}}Edit{{else}}Add{{/if}} Todo</h1>
    <form action="{{ctxPath}}/t/app/todo/save" method="post">
      <input type="hidden" name="id" value="{{todo.id}}">
      <div class="mb-3">
        <label class="form-label">Title</label>
        <input type="text" name="title" class="form-control" value="{{todo.title}}" required>
      </div>
      <div class="form-check mb-3">
        <input type="checkbox" name="done" class="form-check-input" {{#if todo.done}}checked{{/if}}>
        <label class="form-check-label">Done</label>
      </div>
      <button class="btn btn-primary">Save</button>
      <a href="{{ctxPath}}/t/app/todo" class="btn btn-link">Cancel</a>
    </form>
  </div>
</body>
</html>
```

Scale this up for larger entities (more fields, related tables, validation) but keep the structure: one SQL script, one transaction per entity, the default view auto-rendered (no render call) plus extra `.html` views only as needed, GET for reads, POST+redirect for writes.

## Flash messages (OPTIONAL — only when asked)

Default is the query param above. If the user wants true flash messages (survive one redirect, then gone, not visible in the URL), implement them on the session via a shared base class so all transactions reuse the same helpers. The read-**then**-remove order is what makes them show exactly once:

```python
class Base(object):
    def set_flash(self, ctx, text):
        ctx.getRequest().getSession(True).setAttribute("flash", text)

    def get_flash(self, ctx):
        session = ctx.getRequest().getSession(True)
        msg = session.getAttribute("flash")   # read
        session.removeAttribute("flash")      # then remove
        ctx.output["flash"] = msg
```
Call `self.set_flash(ctx, "Saved")` before the redirect in a POST action; call `self.get_flash(ctx)` at the start of the next GET; show `{{flash}}` in the view. The transaction must inherit `Base`: `class Todo(Base):`. If the app also uses a page layout, put both `page_layout` and the flash helpers on the same `Base` class.
