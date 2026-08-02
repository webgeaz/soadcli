# Views (Handlebars.java)

Views are HTML files in the `_{code}/` folder, populated from `ctx.output`. **The default view `_{code}/{code}.html` renders automatically when a method leaves `ctx.go_to` unset** — so a simple `view()` needs no `render` call at all. Call `render.as_view(ctx, "other")` only to render a *different* view. Use `{{ctxPath}}` for links; inside an `{{#each}}` loop use `{{../ctxPath}}` to reach the parent context. Generated pages are **full standalone HTML** (`<!DOCTYPE html>` … `</html>`) unless using a layout.

```html
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">

<h1>{{page_title}}</h1>

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
```

## Built-in & logical helpers

`if`, `else`, `unless`, `each`, `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `and`, `or`, `not`, `in`.

Block form `{{#eq role "admin"}}…{{/eq}}` and inline-condition form both work:
```html
{{#eq status "pending"}}<span>Pending</span>{{else}}<span>Active</span>{{/eq}}
{{#if (eq role "admin")}}<p>Admin</p>{{/if}}
{{#if (in user_role_id allowed_roles)}}Granted{{else}}Denied{{/if}}
```
Use `{{#eq}}` for equality — **`{{#if_eq}}` does NOT exist in SØAD**, do not use it. Inside `{{#each}}`, the current item is `{{this}}`.

**No `range` helper.** Handlebars has no built-in range/counter. Build the list in the transaction and loop over it:
```python
ctx.output["page_numbers"] = list(range(1, total_pages + 1))
```
```html
{{#each page_numbers}}<a href="?page={{this}}">{{this}}</a>{{/each}}
```

## SØAD custom helpers

**`ref_lookup`** — fetch a column value from a table by key:
```html
{{ref_lookup user.id table="user" label="login_id" value="id"}}
```
`label` defaults to `name`, `value` defaults to `id`. Multiple labels: `label="name|email"`. Inside a loop: `{{ref_lookup this.id table="user_details" label="full_name" value="user_id"}}`.

**`select` / `option`** — dropdown from a table:
```html
{{select table="countries" selected=selected_country label="name" value="code"}}
```
Params: `table`, `refs`, `filter="active=1"`, `id`, `name`, `class`, `label`, `value`, `selected`, `required`, `readonly`, `sel_text` (placeholder, default "Please Select"). Use `{{option ...}}` (same params) for just the `<option>`s inside your own `<select>`.

**`dateFmt`** — format a date (default `dd/MM/yyyy`):
```html
{{dateFmt registration_date "yyyy-MM-dd"}}
```

**`html`** — sanitize text, convert newlines to `<br>`, auto-link URLs: `{{html content}}`.

**`session`** — read a session attribute: `{{session "user_id"}}`.

**`get`** — read a `ctx.output` key containing spaces/special chars: `{{get "complex key-name"}}`.

**`i18n`** — localized string from `messages.properties`: `{{i18n "welcome.message"}}`. Set locale via session attribute `__locale__` (e.g. `request.getSession(True).setAttribute("__locale__", "ms")`); strings live in `messages.properties` / `messages_ms.properties`.

## Edit-form patterns (both valid — choose per situation)

**A. Reuse the list view (official tutorial style).** One view shows both the list and an add/edit form; `edit` loads the record then calls `view`:
```python
# from models import Contact as ContactModel  # if transaction class is also Contact
def edit(self, ctx):
    ctx.output["contact"] = ContactModel.findById(ctx.getRequest().getParameter("id"))
    self.view(ctx)              # reuse the list+form template
```
The shared form binds `value="{{contact.name}}"` (empty when adding). Good for simple screens.

**B. Separate form view.** A dedicated `form` action/template for add+edit, list stays clean. Better when the form is large:
```python
def form(self, ctx):
    id = ctx.getRequest().getParameter("id")
    if id:
        ctx.output["item"] = ItemModel.findById(id)   # use model alias if names collide
    ctx.go_to = render.as_view(ctx, "form")
```
Either way, a single `save` action handles both insert (no id) and update (id present), then PRG-redirects with `ctx.go_to = ctx.ctxPath + "/t/..."`. Mutating methods need docstring exactly `"""POST"""`. With the default auto-increment `id`, never set `id` in Python — load with `findById` when present (non-empty), otherwise `Model()`, then always `saveIt()` (see models-and-sql.md). If model name == transaction class name, alias the model (`as XxxModel`).

## Page layout (OPTIONAL)

Default is **no layout** — each view is a full standalone HTML page. Only add a layout when the user wants a shared chrome (header/nav/footer).

### How it works

1. Write the layout as a **normal transaction** (e.g. `src/org/layout/layout.py`) whose class implements `page_layout(self, ctx)`.
2. Other transactions **inherit** that class: `class Dashboard(Layout):`.
3. `page_layout` returns a tuple pointing at the layout's view:
   - **2-tuple** `(group, code)` — view name defaults to the code (renders `_layout/layout.html`).
   - **3-tuple** `(group, code, view)` — use when the layout template file name differs.
4. **Auto-render still applies:** leave `ctx.go_to` unset for the default page view; the framework renders `_{code}/{code}.html` and wraps it with the layout.
5. **Extra views:** `ctx.go_to = render.as_view(ctx, "form")` still works — the layout wraps that view too when the transaction inherits `Layout`.
6. **JSON / redirects / fragments:** if you set `ctx.go_to` to a redirect string, `render.as_json`, or an htmx fragment, you are not rendering a full page — the layout does not apply (that is correct).

```python
# src/org/layout/layout.py
class Layout(object):
    def page_layout(self, ctx):
        return ("org", "layout")          # 2-tuple; or ("org", "layout", "layout")
```
```python
# src/org/dashboard/dashboard.py
from default.org.layout import Layout     # default. prefix maps to src/

class Dashboard(Layout):                  # inherit the layout
    def view(self, ctx):
        ctx.output["page_title"] = "Dashboard"
        # ctx.go_to unset => auto-render default view; layout wraps it

    def form(self, ctx):
        ctx.go_to = render.as_view(ctx, "form")   # also wrapped by layout
```
The layout HTML uses placeholders `{{&title}}`, `{{&head}}`, `{{&body}}`; the page view's content is injected into `{{&body}}`. Page templates hold only their own content (no full document shell when using a layout) — the layout supplies the surrounding header/nav/footer. Inheriting the layout class also lets transactions share helper methods (e.g. an auth check or flash helpers).
