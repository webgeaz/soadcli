# SØAD Framework — Coding Context (Web Chat)

SØAD is a convention-over-configuration MVC web framework on the JVM. Controllers (called **Transactions**) are written in **Jython** (Python 2.7 syntax on Java), views in **Handlebars.java**, models via **ActiveJDBC** (auto-generated from DB tables). Use this file as context when writing transaction code, view templates, or SQL for the **web IDE / paste** workflow (labeled code blocks for the developer to apply).

**Naming:** Canonical spelling is **SØAD**. "SOAD" and "soad" are accepted shorthand — treat them as identical on input. Use **SØAD** in generated prose, docs, and comments. Keep lowercase `soad` as-is in code identifiers, module names, and file paths — do NOT "correct" those.

---

## HARD RULES (DO NOT VIOLATE)

These break code silently if ignored. They always apply.

- **Language is Jython = Python 2.7 syntax**, running on the JVM (not CPython).
- **DO NOT use f-strings.** `f"Hi {name}"` does NOT work. Use `%` (`"Hi %s" % name`) or `.format()` (`"Hi {}".format(name)`) — both work.
- **`except Exception as e:` IS allowed** (verified in this Jython build) — use it.
- **`print()` works**, but in containers its output may not reach the IDE log. Prefer `Log.info(ctx, "...")` for anything that must be visible.
- **DO NOT use pip or any CPython package** (`requests`, `numpy`, `pandas`, etc.) — they do not exist here.
- **Add libraries as Java JARs only.** Import Java classes directly, e.g. `from java.io import File`, `from java.time import LocalDateTime`. Bundled: Guava, Apache Commons (lang3, io, text), Apache POI (Office docs), openpdf (PDF). Full version list in the Utilities section.
- **DO NOT write any routing/config file.** Routing is convention-based from folder/file/method names.
- **DO NOT hand-write Model classes.** They are auto-generated from DB tables; just `from models import Capitalizedname`. The class name is the **table name with the first letter capitalized and the rest exact — NO English inflection.** SØAD disables ActiveJDBC's default pluralization, so `persons` → `Persons` (not `Person`), `categories` → `Categories` (not `Category`). Match the table spelling exactly.
- **On any name clash involving a model, alias the model as `XxxModel`.** Keep transaction class names unaliased (routing and inheritance need the real name).
  - Own class: `from models import Todo as TodoModel` then `class Todo(object):` — very common.
  - Cross-import: if you import another transaction with the same name as a model you use, alias the model (`from models import Members as MembersModel`); keep the transaction import real for inheritance (`class X(Members):`).
  - No clash: different names need no alias (`from models import Product` inside `class Api` is fine).
- **Primary key default is auto-increment.** Prefer `id INT PRIMARY KEY AUTO_INCREMENT` unless the user explicitly asks for UUID. Match the table definition to the Python code — never mix the two approaches:
  - **Auto-increment (`INT`)** — do **NOT** set `id` in code. Always use **`saveIt()`** for both insert and update. The DB assigns the id.
  - **UUID (`VARCHAR(36)`)** — only when the user asks. Generate and `set("id", ...)` yourself. Use **`insert()`** for a NEW record, **`saveIt()`** for updates. Calling `saveIt()` on a manually-id'd new record silently runs an UPDATE and inserts nothing.
- **Timestamps: default to `created_date` / `updated_date`.** For **new** tables, use those column names and set them in code with `LocalDateTime.now()`. Do **not** invent `created_at`/`updated_at` on new tables. If an **existing** table already has `created_at`/`updated_at`, those are ActiveJDBC magic columns — never `.set()` them (throws); the framework manages them.
- **Every action method takes `ctx`:** `def view(self, ctx):`. All public methods on a transaction class are reachable as URL actions.
- **POST-only actions:** for create/update/delete (any state-changing method), the method docstring must be exactly `"""POST"""` (the word `POST` alone). That restricts the action to HTTP POST. Omitting it leaves the method callable via GET too — never omit on mutating actions. Do not invent `@post`, comments, or other markers. Read-only GET actions need no special docstring.
- **Default class base is `object`:** `class Foo(object):`. Layout/base inheritance is optional.
- **Auto-render: if a method never assigns `ctx.go_to`, the framework renders the default view `_{code}/{code}.html` automatically.** Do NOT call `render.as_view` just to render the default view — leave `ctx.go_to` unset. Assign `ctx.go_to` ONLY for something else: a *different* view (`render.as_view(ctx, "other")`), JSON, a file, or a redirect string. Prefer the default view first; add extra `.html` views only when a transaction needs more than one screen.
- **Redirects and links must include the context path.** In Python: `ctx.go_to = ctx.ctxPath + "/t/{group}/{code}..."`. In HTML: `href="{{ctxPath}}/t/..."` (inside `{{#each}}` use `{{../ctxPath}}`). Never hardcode bare `"/t/..."` for redirects — apps often run under a non-root context path.

---

## Routing

URL pattern: **`/t/{group}/{code}/{action}`**
- `/t` fixed prefix · `{group}` folder/module · `{code}` = `.py` filename AND class name (capitalized) · `{action}` = method, **defaults to `view`** if omitted.
- `/t/web/home` → group `web`, code `home`, class `Home`, method `view()`
- `/t/app/user/edit?id=5` → `User.edit()`, read `id` from request

On disk (transaction `example/contact`) — **web IDE / flat layout:**
```
example/
  contact.py            # class Contact
  _contact/             # views: underscore + code name
    contact.html        # default view (matches code name)
    edit.html           # optional extra views
```
Class name = code with first letter capitalized (`address_book` → `Address_book`).

### Imports

- **Built-in SØAD utilities and models — no prefix:** `from utils import render`, `from models import Members`.
- **Name clash → always alias the model (`as XxxModel`), never the transaction class you own or inherit from:**
  ```python
  from models import Members as MembersModel          # model alias
  from default.org.members import Members             # transaction — keep real name for inheritance
  class Roster(Members):                              # base class needs real name
      def view(self, ctx):
          ctx.output["rows"] = MembersModel.findAll()
  ```
- **Custom transactions/utilities/layouts — `default.` prefix** (resolves to the transaction at `{group}/{code}.py`):
  - `from default.org.members import Members` — the `org/members` transaction (`org/members.py`)
  - `from default.utils.member_number_generator import MemberNumberGenerator` — helper transaction
  - `from default.org.layout import Layout` — shared layout is a normal transaction others inherit

  Pattern: `default.<group>.<code>` → the Capitalized class in `{group}/{code}.py`.

---

## Transaction skeleton

```python
from models import Contact as ContactModel   # alias: same name as transaction class
from java.time import LocalDateTime

class Contact(object):
    def view(self, ctx):                      # GET, default action — no POST docstring
        ctx.output["contacts"] = ContactModel.findAll().orderBy("name ASC")
        # No ctx.go_to assignment => auto-renders _contact/contact.html

    def save(self, ctx):
        """POST"""                            # exact docstring required — POST-only
        r = ctx.getRequest()
        id = r.getParameter("id")             # "" on create form => falsy => insert
        # findById accepts str or int — pass request param as-is, no int(id)
        # Auto-increment default: never set("id", ...); always saveIt()
        c = ContactModel.findById(id) if id else ContactModel()
        c.set("name", r.getParameter("name"))
        if not id:
            c.set("created_date", LocalDateTime.now())
        c.set("updated_date", LocalDateTime.now())
        c.saveIt()
        ctx.go_to = ctx.ctxPath + "/t/example/contact"   # always prefix redirects with ctxPath
```
`render` is only imported when a method needs a non-default response (a different view, JSON, file, PDF). The skeleton above needs no `render` import.

---

## ctx (WebContext)

- `ctx.getRequest()` / `ctx.getResponse()` — servlet request/response
- `ctx.output` — map of data passed to the view
- `ctx.go_to` — the response. **Unset → auto-renders the default view `_{code}/{code}.html`**; **string → redirect** (`sendRedirect`); **`render.*` result → that rendered output**
- `ctx.ctxPath` — app context path (may be `""` or e.g. `"/myapp"`). **Always** prefix redirect strings: `ctx.go_to = ctx.ctxPath + "/t/..."`. In views: `{{ctxPath}}`.
- `ctx.getGroup()`, `ctx.getCode()`, `ctx.getMethod()`, `ctx.getAppName()`
- Read input: `ctx.getRequest().getParameter("name")`
- Session: `ctx.getRequest().getSession(True)`

---

## Models (ActiveJDBC — auto-generated)

Never define a model class — import it by its table name with the **first letter capitalized and the rest kept exactly as-is**. Table `contact` → `Contact`; `hr_employee` → `Hr_employee`; `persons` → `Persons`; `categories` → `Categories`.

**DO NOT apply English inflection.** Stock ActiveJDBC maps `persons` → `Person` and `boxes` → `Box` by default — **SØAD disables this and uses strict exact naming.** So `persons` is `Persons` (NOT `Person`), `categories` is `Categories` (NOT `Category`), `people` is `People`. Always the literal table name with a capital first letter, including any plural `s`.

**Name collision — always alias the model as `XxxModel`:** if the model name equals the current transaction class **or** an imported transaction used in the same file, alias the model and keep transaction names real (routing + inheritance).

```python
from models import Contact as ContactModel   # when class Contact is the transaction
# use ContactModel.findAll(), ContactModel(), etc.
```

No alias needed when names differ (`from models import Product` inside `class Api` is fine).

```python
from models import Contact

c = Contact()                                  # create
c.set("name", "John"); c.set("email", "j@x.com")
c.saveIt()

Contact.findAll()                              # read
Contact.findById(1)
Contact.where("name LIKE ?", "%John%")
Contact.findAll().orderBy("name ASC").limit(10)
Contact.findAll().orderBy("grade DESC, name ASC")

c = Contact.findById(1)                        # update
c.set("name", "Jane"); c.saveIt()

c.delete()                                     # delete

Contact.findAll().toMaps()                     # list of dict — handy for render.as_json

# Single record by condition: use Model.first(...), NOT .where(...).first()
c = Contact.first("name = ?", "John")          # correct
# c = Contact.where("name = ?", "John").first()  # WRONG — LazyList has no .first()
```

**`findById` accepts any object** — both `int` and `str` work. Request parameters are strings; pass them through as-is, **do not cast** with `int(id)`:

```python
id = r.getParameter("id")          # always a string (or None / "")
c = Contact.findById(id)           # OK for INT or VARCHAR(36) PKs
# Contact.findById(int(id))        # unnecessary; avoid — breaks on empty ""
```

**Empty / missing id means create.** A create form's hidden field often posts `id=""`; empty string is falsy:

```python
id = r.getParameter("id")
c = Contact.findById(id) if id else Contact()   # "" or None => new row
# Do NOT use `if id is not None` — empty string is not None but still means create
```

The framework wraps each request in a DB transaction: **auto-commit on success, auto-rollback on any exception.** Do NOT manage transactions manually. To force a rollback, raise an exception.

### Timestamp columns

**Default for all new tables: `created_date` / `updated_date` (DATETIME).** Set them in Python yourself. Do **not** create `created_at`/`updated_at` columns on new tables unless the user explicitly asks for ActiveJDBC auto-managed timestamps.

```python
from java.time import LocalDateTime

# insert
c = Contact()
c.set("name", "John")
c.set("created_date", LocalDateTime.now())
c.set("updated_date", LocalDateTime.now())
c.saveIt()

# update
c.set("name", "Jane")
c.set("updated_date", LocalDateTime.now())
c.saveIt()
```

**Existing tables only — magic `created_at` / `updated_at`:** if a table already has these Timestamp columns, ActiveJDBC auto-sets them. **Never** call `obj.set("created_at", ...)` or `obj.set("updated_at", ...)` — that throws in SØAD. Leave them alone in code.

### Primary keys: auto-increment (default) vs UUID (opt-in)

**Prefer `id INT PRIMARY KEY AUTO_INCREMENT` unless the user explicitly asks for UUID.** The SQL column type and the Python insert path must match. Do not mix them.

#### Default — auto-increment (`INT`)

| SQL | Python |
|---|---|
| `id INT PRIMARY KEY AUTO_INCREMENT` | Never set `id`. Always `saveIt()` for insert **and** update. |

```python
c = Contact()
c.set("name", "John")
# DO NOT set id
c.saveIt()                       # INSERT (id auto-filled)
```

#### Opt-in only — UUID (`VARCHAR(36)`)

Use **only when the user asks** for UUID / string ids.

| SQL | Python |
|---|---|
| `id VARCHAR(36) PRIMARY KEY` | Generate and `set("id", ...)` on create. **`insert()`** for NEW rows; **`saveIt()`** for updates. |

```python
from java.util import UUID

m = Members()
m.set("id", str(UUID.randomUUID()))
m.set("name", "John")
m.insert()                       # correct: INSERT
# m.saveIt()  # WRONG on new + manual id: silent no-op

# Add/edit in one method (UUID only)
new_record = False
if record_id:
    record = Members.findById(record_id)
else:
    record = Members()
    record.set("id", str(UUID.randomUUID()))
    new_record = True
record.set("name", "value")
if new_record:
    record.insert()
else:
    record.saveIt()
```

### BIT / checkboxes

- Store as `BIT`; ActiveJDBC maps to Java/Python **boolean**.
- **HTML checkbox:** only posts a value when checked. Unchecked → parameter missing/`None`.
- **Set from form:** `obj.set("done", r.getParameter("done") == "on")` — `True` if checked, `False` if not.
- **Query:** `Model.where("done = ?", False)` or `True` — use Python booleans.

---

## SQL (run in the IDE SQL editor)

**You do not apply DDL yourself.** When a task needs a new table or column:

- **Show the SQL as a fenced `sql` code block in your reply.** Do not invent migration file paths or write `.sql` files unless the user asks for a specific path.
- Tell the developer to **run it in the IDE SQL editor**, then **Introspect** to regenerate the models. In-IDE schema changes regenerate models automatically; only external changes need a manual Introspect.
- One logical change per block (a `CREATE` or an `ALTER`) so they can be run in order.
- **Seed/sample data:** provide it the same way (a code block) only when the user explicitly asks — never by default.

Rules for `CREATE TABLE` so the auto-generated model aligns:

- **Every table MUST have a PK column named `id`.** **Default: `INT PRIMARY KEY AUTO_INCREMENT`.** Use `VARCHAR(36) PRIMARY KEY` only if the user asks for UUID — then the Python code must set the id and use `insert()`/`saveIt()` as above.
- **Model class name = table name with first letter capitalized, rest exactly as-is. NO inflection** — `persons` → `Persons` (not `Person`), `categories` → `Categories`.
- **A BLOB column auto-expands into THREE columns.** `resume` (BLOB) → `resume`, `resume_fn`, `resume_ft`. Do NOT manually add the `_fn`/`_ft` columns.
- **Table naming:** simple single-feature apps may use a bare name matching the code (`todo` table + `todo` transaction). For multi-module apps, **prefix by group** to avoid clashes (`hr_employee`, `sales_order`). The model then becomes `Hr_employee` / `Sales_order` (first letter only capitalized).
- After schema changes **outside** the IDE, run **Introspect** to regenerate models. In-IDE changes regenerate automatically.

Supported types: `VARCHAR(n)`, `TEXT`, `MEDIUMTEXT`, `INT`, `BIGINT`, `BIT`, `DECIMAL(n,d)`, `DATE`, `DATETIME`, `TIME`, `BLOB`, `MEDIUMBLOB`.

**MySQL → Java type mapping** (use correct Java type in `.set()` and reads):

| MySQL | Java type |
|---|---|
| VARCHAR / TEXT / MEDIUMTEXT | String |
| INT | Integer |
| BIGINT | java.math.BigInteger |
| BIT | Boolean |
| DECIMAL | java.math.BigDecimal |
| DATE | java.sql.Date |
| DATETIME | **java.time.LocalDateTime** |
| TIME | java.sql.Time |
| BLOB / MEDIUMBLOB | byte[] |

```python
from java.time import LocalDateTime
obj.set("created_date", LocalDateTime.now())
```

Example `CREATE TABLE` (show this in your reply for the developer to run):
```sql
CREATE TABLE contact (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    contact_no VARCHAR(20),
    email VARCHAR(100),
    created_date DATETIME,
    updated_date DATETIME
);
```
→ auto-generates model class `Contact`. A later change is a separate `ALTER` block:
```sql
ALTER TABLE contact ADD COLUMN company VARCHAR(120);
```

---

## Render methods (`from utils import render`)

**First: you often don't need `render` at all.** If a method leaves `ctx.go_to` unset, the framework auto-renders the default view `_{code}/{code}.html`. Use the methods below only to return something *other* than the default view, assigning the result to `ctx.go_to`.

```python
render.as_view(ctx, view, group=None, code=None)   # Handlebars HTML (most common)
render.as_json(ctx, obj=None)                        # JSON; defaults to ctx.output
render.as_html(ctx, code=None)                       # raw HTML file, no Handlebars
render.as_string(ctx, text)                          # raw string/HTML
render.as_file(ctx, file, content_type, filename=None, attachment=True)
render.as_blob(ctx, data, content_type, filename, attachment=False)  # filename required
render.as_pdf(ctx, view, group=None, code=None, filename=None, attachment=False)
```

- `as_view(ctx, "home")` renders `_home/home.html` in the current group. Pass `group=`/`code=` to render a view from another transaction.
- **`render.as_view(...)` returns a callable.** Assign to `ctx.go_to` for normal rendering. To get the HTML **as a string** (email body, PDF input), call it with a trailing `()`:
  ```python
  html = render.as_view(ctx, "invoice")()   # note the extra ()
  ```
- `as_json` with a model list: `render.as_json(ctx, Contact.findAll().toMaps())`.
- `as_file` — `attachment=False` displays inline (e.g. show an image in browser).
- `as_blob` — binary already in memory (e.g. DB BLOB or POI output). **`filename` is required** (not optional).
- `as_pdf` — template must be well-formed XHTML (openpdf-backed HTML→PDF).

---

## Views (Handlebars.java)

Views are HTML files in the `_{code}/` folder, populated from `ctx.output`. **The default view `_{code}/{code}.html` renders automatically when a method leaves `ctx.go_to` unset** — a simple `view()` needs no `render` call. Call `render.as_view(ctx, "other")` only to render a *different* view. Generated pages are **full standalone HTML** (`<!DOCTYPE html>` … `</html>`) unless using a layout. Use `{{ctxPath}}` for links; inside `{{#each}}` use `{{../ctxPath}}`.

```html
<!DOCTYPE html>
<html>
<head>
  <title>{{page_title}}</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
  <div class="container py-4">
    {{#if contacts}}
      <ul>
        {{#each contacts}}
          <li>{{name}} — {{email}}
            <a href="{{../ctxPath}}/t/example/contact/edit?id={{id}}">Edit</a>
          </li>
        {{/each}}
      </ul>
    {{else}}
      <div class="alert alert-info">No items found</div>
    {{/if}}
  </div>
</body>
</html>
```

### Built-in & logical helpers

`if`, `else`, `unless`, `each`, `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `and`, `or`, `not`, `in`.

Block form and inline-condition form both work:
```html
{{#eq status "pending"}}<span>Pending</span>{{else}}<span>Active</span>{{/eq}}
{{#if (eq role "admin")}}<p>Admin</p>{{/if}}
{{#if (in user_role_id allowed_roles)}}Granted{{else}}Denied{{/if}}
```
Use `{{#eq}}` for equality — **`{{#if_eq}}` does NOT exist in SØAD**, do not use it. Inside `{{#each}}`, current item is `{{this}}`.

**No `range` helper.** Build the list in the transaction and loop over it:
```python
ctx.output["page_numbers"] = list(range(1, total_pages + 1))
```
```html
{{#each page_numbers}}<a href="?page={{this}}">{{this}}</a>{{/each}}
```

### SØAD custom helpers

**`ref_lookup`** — fetch a column value from a table by key:
```html
{{ref_lookup user.id table="user" label="login_id" value="id"}}
```
`label` defaults to `name`, `value` defaults to `id`. Multiple labels: `label="name|email"`. Inside a loop: `{{ref_lookup this.id table="user_details" label="full_name" value="user_id"}}`.

**`select` / `option`** — dropdown from a table:
```html
{{select table="countries" selected=selected_country label="name" value="code"}}
```
Params: `table`, `refs`, `filter="active=1"`, `id`, `name`, `class`, `label`, `value`, `selected`, `required`, `readonly`, `sel_text` (placeholder, default "Please Select"). Use `{{option ...}}` for just the `<option>`s inside your own `<select>`.

**`dateFmt`** — format a date (default `dd/MM/yyyy`): `{{dateFmt registration_date "yyyy-MM-dd"}}`.

**`html`** — sanitize text, newlines → `<br>`, auto-link URLs: `{{html content}}`.

**`session`** — read a session attribute: `{{session "user_id"}}`.

**`get`** — read a `ctx.output` key with spaces/special chars: `{{get "complex key-name"}}`.

**`i18n`** — localized string: `{{i18n "welcome.message"}}`. Set locale via session attribute `__locale__`; strings live in `messages.properties` / `messages_ms.properties`.

**`length` / `size`** — element count of a list/collection/array (same helper, two names): `{{length items}}`, `{{#if (gt (size items) 0)}}...{{/if}}`. Missing/`null` returns `0`. Handlebars templates have **no method-call syntax** — `{{items.size()}}` / `{{products.size()}}` is **NOT valid** and will fail to render; always use the helper: `{{size items}}` (or `{{length items}}`), never `{{items.size()}}`.

### Edit-form patterns (both valid)

**A. Reuse the list view** — one view shows list + form; `edit` loads the record then calls `view`. Good for simple screens:
```python
# from models import Contact as ContactModel  # if transaction class is also Contact
def edit(self, ctx):
    ctx.output["contact"] = ContactModel.findById(ctx.getRequest().getParameter("id"))
    self.view(ctx)
```

**B. Separate form view** — dedicated `form` action/template for add+edit, list stays clean. Better for large forms:
```python
def form(self, ctx):
    id = ctx.getRequest().getParameter("id")
    if id:
        ctx.output["item"] = ItemModel.findById(id)   # use model alias if names collide
    ctx.go_to = render.as_view(ctx, "form")
```
Either way, a single `save` handles both insert (no id / empty hidden field) and update (id present), then PRG-redirects with `ctx.go_to = ctx.ctxPath + "/t/..."`. Mutating methods need docstring exactly `"""POST"""`. With auto-increment: never set `id` in Python — `findById` accepts the request string as-is.

### Page layout (OPTIONAL)

Default is **no layout** — each view is a full standalone HTML page. Only add a layout when the user wants shared chrome (header/nav/footer).

1. Write the layout as a **normal transaction** (e.g. `org/layout.py`) whose class implements `page_layout(self, ctx)`.
2. Other transactions **inherit** that class: `class Dashboard(Layout):`.
3. `page_layout` returns a tuple pointing at the layout's view:
   - **2-tuple** `(group, code)` — view name defaults to the code (renders `_layout/layout.html`).
   - **3-tuple** `(group, code, view)` — when the layout template file name differs.
4. **Auto-render still applies:** leave `ctx.go_to` unset for the default page view; the framework renders `_{code}/{code}.html` and wraps it with the layout.
5. **Extra views:** `ctx.go_to = render.as_view(ctx, "form")` is also wrapped by the layout when the transaction inherits `Layout`.
6. **JSON / redirects / fragments:** if you set `ctx.go_to` to a redirect string, `render.as_json`, or an htmx fragment, you are not rendering a full page — the layout does not apply (that is correct).

```python
# org/layout.py
class Layout(object):
    def page_layout(self, ctx):
        return ("org", "layout")          # or ("org", "layout", "layout")
```
```python
# org/dashboard.py
from default.org.layout import Layout

class Dashboard(Layout):
    def view(self, ctx):
        ctx.output["page_title"] = "Dashboard"
        # ctx.go_to unset => auto-render default view; layout wraps it

    def form(self, ctx):
        ctx.go_to = render.as_view(ctx, "form")   # also wrapped by layout
```
Layout HTML uses placeholders `{{&title}}`, `{{&head}}`, `{{&body}}`; the page view's content is injected into `{{&body}}`. When using a layout, page templates hold only their own content (no full document shell). Inheriting the layout class also shares helper methods (e.g. auth check or flash helpers).

---

## File Upload

The form must use `method="post"` and `enctype="multipart/form-data"` with an `<input type="file" name="X">`. SØAD exposes **three** request parameters per file input:

- `X` → request-scoped `UploadedFile` object (**not** a `byte[]`)
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

        # writeTo() streams the file and is preferred for large uploads
        uploaded_file.writeTo(File("/tmp/uploads/" + fname))
        ctx.output["message"] = "Uploaded: " + fname
        ctx.go_to = render.as_view(ctx, "upload_status")
```

`UploadedFile` methods include `getFileName()`, `getContentType()`, `getSize()`, `getInputStream()`, `writeTo(destination)`, and `getBytes()`.

- Upload data is deleted automatically after the request finishes. Save or consume it inside the transaction; do not defer file access.
- Prefer `getInputStream()` / `writeTo()` for large files. `getBytes()` loads the whole file into memory and should only be used after enforcing a small size limit.
- Do **not** call `len(uploaded_file)` or `GuavaFiles.write(uploaded_file, ...)`: the parameter is an object, not `byte[]`. Use `getSize()` and `writeTo()`.
- `maxfileuploadsize` limits each file; `maxrequestuploadsize` limits the complete multipart request (default: file limit + 1 MiB); `fileuploadtempdir` selects the spool directory (default: `${java.io.tmpdir}/soad-uploads`).
- To store an upload in the DB, use a BLOB column. Setting `resume` also populates `resume_fn` and `resume_ft`; serve it with `render.as_blob(ctx, content, ftype, fname, attachment=False)`.

---

## Logging (`from sufia.util import Log`)

```python
from sufia.util import Log

Log.info(ctx, "message")
Log.debug(ctx, "params: %s" % ctx.getAllParameters())
Log.warn(ctx, "warning")
Log.error(ctx, "failed: %s" % str(e))   # optional 3rd arg: exception object
Log.print(ctx, "same as info")
Log.trace(ctx, "very detailed")
```
Prefer `Log.*` over `print()`. Use `%` formatting (never f-strings). Common error pattern:
```python
try:
    ...
except Exception as e:
    Log.error(ctx, "Error: %s" % str(e))
    raise       # bare raise — keeps the original traceback (Jython/Python 2)
    # raise e   # WRONG: re-raises a new frame and loses the original traceback
```
Re-raise so the framework rolls back the DB transaction.

---

## Utilities

**Email (`from utils import mailer`):**
```python
mailer.send(sender, receiver, subject, content,
            cc=[], bcc=[], html=False, attachment=[], reply_to=None)
# HTML body from a view:
body = render.as_view(ctx, "welcome_email")()   # trailing ()
mailer.send("from@x.com", "to@x.com", "Subject", body, html=True)
```

**PDF (`from utils import pdf`):**
```python
from utils import pdf, render
html = render.as_view(ctx, "invoice")()        # XHTML string
pdf.generate(html, "/tmp/invoice.pdf")
# Stream to browser instead:
ctx.go_to = render.as_pdf(ctx, "invoice", filename="invoice.pdf", attachment=True)
```

**Bundled Java helpers:**
- File IO: `from com.google.common.io import Files` → `Files.write(bytes, File(path))`, `Files.toString(file, "UTF-8")`
- Base64: `from com.google.common.io import BaseEncoding` → `BaseEncoding.base64().encode(...)`
- Stream: `from com.google.common.io import ByteStreams` → `ByteStreams.copy(in, out)`
- Import Java classes directly; do NOT use pip. Need something else? Drop a JAR into `/webapp/WEB-INF/lib/`.

**Bundled JARs (use when relevant):**
- **guava-33.4.0-jre** — collections, caching, I/O, strings (`com.google.common.*`)
- **commons-io-2.15.1** — file/stream utilities (`org.apache.commons.io.*`)
- **commons-lang3-3.14.0** — core lang utilities (`org.apache.commons.lang3.*`)
- **commons-text-1.11.0** — text processing (`org.apache.commons.text.*`)
- **poi-5.4.0** — Apache POI: Excel, Word, PowerPoint (`org.apache.poi.*`)
- **openpdf-2.0.3** — PDF generation (backs `utils.pdf` / `render.as_pdf`)

---

## Integrations

### JSON API
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

### AJAX (jQuery — bundled)
```html
<script>
$("#load").on("click", function () {
  $.getJSON("{{ctxPath}}/t/api/products", function (data) {
    $("#list").empty();
    $.each(data, function (i, p) { $("#list").append("<li>" + p.name + "</li>"); });
  });
});
</script>
```
For POSTs: `$.post("{{ctxPath}}/t/api/create", {name: "X"}, cb, "json")`.

### htmx (bundled)
```html
<button hx-get="{{ctxPath}}/t/app/todo/count" hx-target="#out" hx-swap="innerHTML">
  Refresh
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
Return just the HTML fragment, not a full page (no full `<!DOCTYPE html>` shell for partials).

### DataTables (bundled)
```html
<table id="grid" class="table">
  <thead><tr><th>Name</th><th>Email</th></tr></thead>
  <tbody>
    {{#each contacts}}
    <tr><td>{{name}}</td><td>{{email}}</td></tr>
    {{/each}}
  </tbody>
</table>
<link href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css" rel="stylesheet">
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
<script>$(function () { $("#grid").DataTable(); });</script>
```
For large datasets use server-side mode, pointing `ajax` at a JSON transaction.

### Excel export (Apache POI — bundled)
```python
from org.apache.poi.xssf.usermodel import XSSFWorkbook
from java.io import ByteArrayOutputStream

class Report(object):
    def export(self, ctx):
        wb = XSSFWorkbook()
        sheet = wb.createSheet("Sales")
        sheet.createRow(0).createCell(0).setCellValue("Product")
        rows = Sale.findAll()
        i = 1
        for s in rows:
            row = sheet.createRow(i)
            row.createCell(0).setCellValue(s.get("product"))
            i += 1
        out = ByteArrayOutputStream()
        wb.write(out); wb.close()
        ctx.go_to = render.as_blob(
            ctx, out.toByteArray(),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "report.xlsx", attachment=True)
```

---

## Generating a Complete Application

When asked to build an app or feature, **always produce in this order, each clearly labeled:**

1. **SQL** (only if a table/column is needed) — as a fenced `sql` code block; tell the user to run it in the IDE SQL editor, then Introspect. You do not apply DDL.
2. **Transaction `.py`** — labeled as `{group}/{code}.py`, with all CRUD actions.
3. **The HTML views** — the default `_{code}/{code}.html` plus any extra views, each as its own labeled block.

Output each artifact as a labeled paste block for the web IDE.

Rules:
- One transaction class per logical entity; all CRUD actions as methods on it.
- **If the model and transaction class share a name, alias the model** (`from models import Todo as TodoModel`). Keep the transaction class name (routing). Same rule for imported transactions that clash with a model name.
- **Prefer the default view.** `view()` leaves `ctx.go_to` unset and auto-renders `_{code}/{code}.html`. Add extra `.html` views (rendered with `render.as_view(ctx, "name")`) only for additional screens like a separate form.
- Full standalone HTML pages (no layout by default); link Bootstrap from CDN.
- Reads are GET (no special docstring). **create, update, delete are POST** — method docstring must be exactly `"""POST"""`. Then PRG-redirect with **`ctx.go_to = ctx.ctxPath + "/t/..."`**.
- **Primary key: default auto-increment.** Never set `id`; always `saveIt()`. UUID only if the user asks.
- **Timestamps on new tables: `created_date` / `updated_date`.** Set both on insert; set `updated_date` on every update.
- **Table names:** bare name matching the code is fine for simple apps (`todo`). Prefix by group only for multi-module apps.
- A single `save` handles both insert (no id / empty hidden field) and update (id present). `findById` accepts the request string as-is; empty string means create.
- **Checkboxes / BIT:** `obj.set("done", r.getParameter("done") == "on")`. Query with Python booleans.
- **No built-in flash scope** — pass messages via `?msg=saved` query param by default. Only implement a session-based flash mechanism if the user explicitly asks (see Flash Messages below).
- Delete is a POST form with a JS `confirm()`, never a bare link.
- Plain Bootstrap table for lists; DataTables only if the user wants sort/search.

### Golden Template — Todo CRUD

The list is the **default view** (`_todo/todo.html`, auto-rendered, no render call). The form is an **extra view** (`_todo/form.html`, rendered explicitly).

**SQL** (show as a code block; the developer runs it in the IDE SQL editor, then Introspect):
```sql
CREATE TABLE todo (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    done BIT DEFAULT 0,
    created_date DATETIME,
    updated_date DATETIME
);
```

**`app/todo.py`:**
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
        # findById accepts str or int — no int(id); never set("id", ...)
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

**`_todo/todo.html`** (default view — filename matches the code):
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

**`_todo/form.html`:**
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

### Flash messages (OPTIONAL — only when asked)

If the user wants messages that survive one redirect then disappear (not in the URL), implement on the session via a shared `Base` class. The read-**then**-remove order makes it show exactly once:

```python
class Base(object):
    def set_flash(self, ctx, text):
        ctx.getRequest().getSession(True).setAttribute("flash", text)

    def get_flash(self, ctx):
        session = ctx.getRequest().getSession(True)
        msg = session.getAttribute("flash")
        session.removeAttribute("flash")       # remove after reading
        ctx.output["flash"] = msg
```
Call `self.set_flash(ctx, "Saved")` before the redirect; `self.get_flash(ctx)` at the start of the next GET; show `{{flash}}` in the view. Transaction must inherit `Base`: `class Todo(Base):`. If also using a page layout, put both `page_layout` and flash helpers on the same `Base` class.
