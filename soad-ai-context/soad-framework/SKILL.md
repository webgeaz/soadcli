---
name: soad-framework
description: >-
  Write code for the SØAD web framework — Jython transactions (*.py), Handlebars view templates (*.html), and the SQL the developer runs in the IDE's SQL editor. Use whenever a task involves building, editing, or explaining SØAD application code: transactions, views, models, routing, CRUD apps, file upload, JSON/AJAX/htmx endpoints, DataTables, Excel/PDF/email output. Also use when working in a local SØAD project that syncs via the soad CLI (soad pull / push / create) — e.g. a src/ tree of group/code/code.py and _code/ html view files, or a .config.json / .soad-checksums.json present. SØAD is also written SOAD or soad.
---

# SØAD Framework

SØAD is a convention-over-configuration MVC web framework on the JVM. Controllers (called **Transactions**) are written in **Jython** (Python 2.7 syntax on Java), views in **Handlebars.java**, models via **ActiveJDBC** (auto-generated from DB tables). This skill helps you write transaction code, view templates, and the SQL the developer runs in the IDE.

**Naming:** Canonical spelling is **SØAD**. "SOAD" and "soad" are accepted shorthand for the same product — treat them as identical on input. Use **SØAD** in generated prose, docs, and comments. Keep lowercase `soad` as-is in code identifiers, module names, and paths — do NOT "correct" those.

## HARD RULES (DO NOT VIOLATE)

These break code silently if ignored. They always apply.

- **Language is Jython = Python 2.7 syntax**, running on the JVM (not CPython).
- **DO NOT use f-strings.** `f"Hi {name}"` does NOT work. Use `%` (`"Hi %s" % name`) or `.format()` (`"Hi {}".format(name)`) — both work.
- **`except Exception as e:` IS allowed** (verified in this Jython build) — use it.
- **`print()` works**, but in containers its output may not reach the IDE log. Prefer `Log.info(ctx, "...")` for anything that must be visible.
- **DO NOT use pip or any CPython package** (`requests`, `numpy`, `pandas`, etc.) — they do not exist here.
- **Add libraries as Java JARs only**; import Java directly, e.g. `from java.io import File`, `from java.time import LocalDateTime`. Bundled: Guava, Apache Commons (lang3, io, text), Apache POI (Office docs), openpdf (PDF). Full version list in `reference/render-and-utils.md`.
- **DO NOT write any routing/config file.** Routing is convention-based from folder/file/method names.
- **DO NOT hand-write Model classes.** They are auto-generated from DB tables; just `from models import Capitalizedname`. The class name is the **table name with the first letter capitalized and the rest exact — NO English inflection.** SØAD disables ActiveJDBC's default pluralization, so `persons` → `Persons` (not `Person`), `categories` → `Categories` (not `Category`). Match the table spelling exactly.
- **On any name clash involving a model, alias the model as `XxxModel`.** Keep transaction class names unaliased (routing and inheritance need the real name). Cases:
  - Own class: `from models import Todo as TodoModel` then `class Todo(object):` — very common.
  - Cross-import: if you `from default.org.members import Members` (another transaction) **and** use the `Members` model in the same file, alias the model: `from models import Members as MembersModel`. Do not alias the imported transaction when it is a base class (`class X(Members):`).
  - No clash: different names need no alias (`from models import Product` inside `class Api` is fine).
- **Primary key default is auto-increment.** Prefer `id INT PRIMARY KEY AUTO_INCREMENT` unless the user explicitly asks for UUID. Match the table definition to the Python code — never mix the two approaches:
  - **Auto-increment (`INT`)** — do **NOT** set `id` in code. Always use **`saveIt()`** for both insert and update. The DB assigns the id.
  - **UUID (`VARCHAR(36)`)** — only when the user asks. Generate and `set("id", ...)` yourself. Use **`insert()`** for a NEW record, **`saveIt()`** for updates. Calling `saveIt()` on a manually-id'd new record silently runs an UPDATE and inserts nothing.
  Details and examples: `reference/models-and-sql.md`.
- **Timestamps: default to `created_date` / `updated_date`.** For **new** tables, use those column names and set them in code with `LocalDateTime.now()`. Do **not** invent `created_at`/`updated_at` on new tables. If an **existing** table already has `created_at`/`updated_at`, those are ActiveJDBC magic columns — never `.set()` them (throws); the framework manages them. Details: `reference/models-and-sql.md`.
- **Every action method takes `ctx`**: `def view(self, ctx):`. All public methods on a transaction class are reachable as URL actions.
- **POST-only actions:** for create/update/delete (any state-changing method), the method docstring must be exactly `"""POST"""` (the word `POST` alone). That restricts the action to HTTP POST. Omitting it leaves the method callable via GET too — never omit on mutating actions. Do not invent `@post`, comments, or other markers. Read-only GET actions need no special docstring.
- **Default class base is `object`:** `class Foo(object):`. Layout/base inheritance is optional.
- **Auto-render: if a method never assigns `ctx.go_to`, the framework renders the default view `_{code}/{code}.html` automatically.** Do NOT call `render.as_view` just to render the default view — leave `ctx.go_to` unset. Assign `ctx.go_to` ONLY when you want something else: a *different* view (`render.as_view(ctx, "other")`), JSON, a file, or a redirect string. Prefer the default view first; add extra `.html` views only when a transaction needs more than one screen.
- **Redirects and links must include the context path.** In Python: `ctx.go_to = ctx.ctxPath + "/t/{group}/{code}..."`. In HTML: `href="{{ctxPath}}/t/..."` (inside `{{#each}}` use `{{../ctxPath}}`). Never hardcode bare `"/t/..."` for redirects — apps often run under a non-root context path.

## Routing

URL pattern: **`/t/{group}/{code}/{action}`**
- `/t` fixed prefix · `{group}` folder/module · `{code}` = `.py` filename AND class name (capitalized) · `{action}` = method, **defaults to `view`** if omitted.
- `/t/web/home` → group `web`, code `home`, class `Home`, method `view()`
- `/t/app/user/edit?id=5` → `User.edit()`, read `id` from request

Class name = code with first letter capitalized (`address_book` → `Address_book`).

### On-disk layout (two modes — do not mix)

**Conceptual / web IDE** (how the server thinks about files — used when pasting into the IDE or describing structure):
```
example/
  contact.py            # class Contact
  _contact/             # views: underscore + code
    contact.html        # default view (matches code)
    edit.html           # optional extra views
```

**Local CLI project** (what exists on disk after `soad pull` / `soad create` — edit these paths):
```
src/
  example/
    contact/
      contact.py        # class Contact
      _contact/
        contact.html
        edit.html
```
Rule: **local CLI = always under `src/<group>/<code>/<code>.py` and `src/<group>/<code>/_<code>/*.html`.** The web-IDE tree is the same group/code/view names without the `src/<group>/<code>/` nesting. When generating for a CLI project, write into the `src/...` paths only.

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
- **Custom transactions/utilities/layouts — `default.` prefix, which maps to `src/`:**
  - `from default.org.members import Members` → `src/org/members/members.py`
  - `from default.utils.member_number_generator import MemberNumberGenerator` → `src/utils/member_number_generator/member_number_generator.py`
  - `from default.org.layout import Layout` → `src/org/layout/layout.py` (a shared layout is just a normal transaction other transactions inherit)

  Pattern: `default.<group>.<code>` always resolves to `src/<group>/<code>/<code>.py` — the same transaction folder structure, no exceptions.

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

## ctx (WebContext) essentials

- `ctx.getRequest()` / `ctx.getResponse()` — servlet request/response
- `ctx.output` — map of data passed to the view
- `ctx.go_to` — the response. **Unset → auto-renders the default view `_{code}/{code}.html`**; **string → redirect** (`sendRedirect`); **`render.*` result → that rendered output**
- `ctx.ctxPath` — app context path (may be `""` or e.g. `"/myapp"`). **Always** prefix redirect strings: `ctx.go_to = ctx.ctxPath + "/t/..."`. In views: `{{ctxPath}}`.
- `ctx.getGroup()`, `ctx.getCode()`, `ctx.getMethod()`, `ctx.getAppName()`
- Read input: `ctx.getRequest().getParameter("name")`
- Session: `ctx.getRequest().getSession(True)`

## Local development with the soad CLI (Claude Code)

**Applies only to local CLI projects** — skip this whole section if you're in a chat with no local SØAD files (no `src/<group>/<code>/` tree, no `.config.json`). In that case you're writing code for the web IDE: produce the `.py`/`.html`/SQL directly and ignore all CLI steps below.

When working in a **local SØAD project** (a `src/` tree synced to the server, with `.config.json` present), **you (the agent) run the `soad` CLI commands yourself via the shell** — do NOT write code and then ask the user to run the commands manually. The CLI is installed and logged in; just run it. The server is the source of truth, so follow this discipline and run the commands directly (no need to ask first for create/pull/push):

- **Creating a new transaction → run `soad create <group>/<code>` yourself first.** Do NOT hand-create the `.py`/`_<code>/` files — `create` scaffolds them correctly on the server and pulls them down. Then edit the pulled files.
- **Editing an existing transaction → run `soad pull <group>/<code>` yourself first** (or `soad pull --all`) to get the current server version before editing, so you don't overwrite newer changes.
- **After editing → run `soad push <group>/<code>` yourself** to upload. One transaction at a time; `soad push-all` pushes everything changed.
- So a typical task is: **run `soad pull` (or `soad create`) → edit files locally → run `soad push`** — all executed by you, end to end. Only tell the user to do something manually if a command actually fails (e.g. auth error).
- Local files live under `src/<group>/<code>/<code>.py` and `src/<group>/<code>/_<code>/*.html`.
- **SQL/DDL is NOT handled by the CLI.** For schema changes in a local project: write a migration file under `db/migrations/` (see models-and-sql.md). In web-IDE/paste mode with no project tree, emit labeled SQL for the user to run — do not invent a migration path. Either way, the user runs SQL in the IDE and runs Introspect; the agent does not apply DDL.
- **DO NOT run `soad delete`, `soad release`, `soad rollback`, `soad deploy`, or `soad clean` unless the user explicitly asks** — they are destructive or release-level. (create/pull/push are safe to run freely.)
- **Testing is optional** — only if the user asks. After a push you can `curl` the live endpoint at `{server}/t/{group}/{code}/{action}` (base URL from `.config.json`'s `--server`). For session apps, ask the user how to log in, then reuse a saved cookie jar; judge success by the response body, not just status. See `reference/cli.md`.

See `reference/cli.md` for the full command list and flags.

## When to read which reference file

Load only what the task needs:

- **`reference/models-and-sql.md`** — any DB work: ActiveJDBC queries/CRUD, SQL delivery (migration files in local CLI vs labeled SQL in paste mode), seed data, the `id` primary-key rule, BLOB triple-column expansion, MySQL→Java type mapping.
- **`reference/views.md`** — writing/editing HTML: Handlebars syntax, all custom helpers (`select`, `ref_lookup`, `dateFmt`, `i18n`, etc.), edit-form patterns, page layout.
- **`reference/render-and-utils.md`** — choosing a render method, returning JSON/file/PDF, logging, sending email.
- **`reference/file-upload.md`** — handling `<input type="file">` uploads.
- **`reference/app-generation.md`** — building a whole app/feature: required output order, conventions, the golden CRUD template, optional flash messages. **Read this whenever asked to "build/generate an app".**
- **`reference/integrations.md`** — htmx, AJAX, JSON APIs, DataTables, Excel export.
- **`reference/cli.md`** — full soad CLI reference: every command, flags, login/config, releases, and optional post-push endpoint testing with curl. Read when running CLI commands beyond the basic pull/push/create loop above, or when the user asks to test.
