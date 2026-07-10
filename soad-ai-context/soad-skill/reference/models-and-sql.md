# Models & SQL

## ActiveJDBC models (auto-generated)

Never define a model class — import it by its table name with the **first letter capitalized and the rest of the name kept exactly as-is**. Table `contact` → `Contact`; `hr_employee` → `Hr_employee`; `persons` → `Persons`; `categories` → `Categories`.

**DO NOT apply English inflection (pluralize/singularize).** Stock ActiveJDBC maps `persons` → `Person` and `boxes` → `Box` by default — **SØAD disables this and uses strict exact naming.** So `persons` is `Persons` (NOT `Person`), `categories` is `Categories` (NOT `Category`), `people` is `People` (NOT `Person`). The class name is always just the literal table name with a capital first letter. Match the table's spelling exactly, including any plural `s`.

**Name collision — always alias the model as `XxxModel`:** if the model name equals the current transaction class **or** an imported transaction/base class used in the same file, alias the model and keep transaction names real (routing + inheritance):

```python
from models import Contact as ContactModel   # own class Contact, or any clash
# use ContactModel.findAll(), ContactModel(), etc.

# Cross-import clash example:
from default.org.members import Members      # transaction base — keep real name
from models import Members as MembersModel   # model gets the alias
class Roster(Members):
    def view(self, ctx):
        ctx.output["rows"] = MembersModel.findAll()
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
Contact.findAll().orderBy("name ASC").limit(10)   # chain
Contact.findAll().orderBy("grade DESC, name ASC")

c = Contact.findById(1)                        # update
c.set("name", "Jane"); c.saveIt()

c.delete()                                     # delete

Contact.findAll().toMaps()                     # -> list of dict, handy for render.as_json

# Single record by condition: use Model.first(...), NOT .where(...).first()
c = Contact.first("name = ?", "John")          # correct
# c = Contact.where("name = ?", "John").first()  # WRONG — LazyList has no .first()
```

**`findById` accepts any object** — both `int` and `str` work. Request parameters are strings; pass them through as-is, **do not cast** with `int(id)`:

```python
id = r.getParameter("id")          # always a string (or None / "")
c = Contact.findById(id)           # OK for INT or VARCHAR(36) PKs
# Contact.findById(1)              # also OK
# Contact.findById(int(id))        # unnecessary; avoid — breaks on empty ""
```

**Empty / missing id means create.** A create form's hidden field often posts `id=""`; empty string is falsy, so:

```python
id = r.getParameter("id")
c = Contact.findById(id) if id else Contact()   # "" or None => new row
# Do NOT use `if id is not None` — empty string is not None but still means create
```

The framework wraps each request in a DB transaction: auto-commit on success, **auto-rollback on any exception**. Do NOT manage transactions manually. To force a rollback, raise an exception.

## Timestamp columns

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
c.set("updated_date", LocalDateTime.now())   # bump on every update
c.saveIt()
```

**Existing tables only — magic `created_at` / `updated_at`:** if a table already has these Timestamp columns, ActiveJDBC auto-sets them (`created_at` on insert, `updated_at` on every update). **Never** call `obj.set("created_at", ...)` or `obj.set("updated_at", ...)` — that throws in SØAD. Leave them alone in code.

## Primary keys: auto-increment (default) vs UUID (opt-in)

**Prefer `id INT PRIMARY KEY AUTO_INCREMENT` unless the user explicitly asks for UUID.** The SQL column type and the Python insert path must match. Do not mix them (e.g. auto-increment table + `set("id", uuid)` or UUID table + `saveIt()` on a new row).

### Default — auto-increment (`INT`)

Use this for all new tables unless told otherwise.

| SQL | Python |
|---|---|
| `id INT PRIMARY KEY AUTO_INCREMENT` | Never set `id`. Always `saveIt()` for insert **and** update. |

```python
# CREATE TABLE contact ( id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(100), ... );

# Insert — do NOT set id; DB generates it
c = Contact()
c.set("name", "John")
c.saveIt()                       # INSERT

# Update — load by id from the request, then saveIt()
c = Contact.findById(id) if id else Contact()
c.set("name", "Jane")
c.saveIt()                       # UPDATE if loaded, INSERT if new (no id set)
```

### Opt-in only — UUID (`VARCHAR(36)`)

Use **only when the user asks** for UUID / string ids.

| SQL | Python |
|---|---|
| `id VARCHAR(36) PRIMARY KEY` | Generate and `set("id", ...)` on create. **`insert()`** for NEW rows; **`saveIt()`** for updates. Never call `saveIt()` on a new record whose id you set — ActiveJDBC treats it as existing and runs an UPDATE that matches nothing (silent no-op). |

```python
from java.util import UUID

# CREATE TABLE members ( id VARCHAR(36) PRIMARY KEY, name VARCHAR(100), ... );

# Insert — set id yourself, then insert() (NOT saveIt)
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
    record.insert()              # new + manual id
else:
    record.saveIt()              # update
```

## Writing CREATE TABLE SQL (run in the IDE SQL editor)

**How you deliver SQL depends on the mode:**

| Mode | What the agent does |
|---|---|
| **Local CLI project** (has `.config.json` / `src/`) | Write a migration **file** under `db/migrations/` (create the folder if needed). Do **not** only print SQL in chat. |
| **Web IDE / paste** (no local project tree) | Emit a **labeled SQL block** in the reply for the user to paste into the IDE SQL editor. Do **not** invent a `db/migrations/` path on disk. |

In **both** modes: the agent never applies DDL. Tell the user to run the SQL in the IDE SQL editor, then run **Introspect** to regenerate models.

**Local CLI migration file rules:**

- Path: **`db/migrations/NNN_verb_name.sql`** — 3-digit zero-padded sequence + descriptive snake_case. E.g. `001_create_todo.sql`, `002_alter_todo_add_priority.sql`.
- **Pick the next number by scanning `db/migrations/` and continuing after the highest existing number.** If the folder is empty or missing, start at `001`.
- One logical change per file: a new table (`create`), or an alter (`alter`). Never edit an already-applied migration — add a new one.
- **Seed/sample data** goes in **`db/seeds/`** (e.g. `db/seeds/seed_category.sql`) and only when the user explicitly asks — not by default.

Then follow these rules so the auto-generated model aligns:

- **Every table MUST have a primary key column named `id`.** **Default: `INT PRIMARY KEY AUTO_INCREMENT`.** Use `VARCHAR(36) PRIMARY KEY` only if the user asks for UUID — then the Python code must set the id and use `insert()`/`saveIt()` as above.
- **Model class name = table name with first letter capitalized, rest exactly as-is. NO inflection** — `persons` → `Persons` (not `Person`), `categories` → `Categories` (not `Category`). SØAD disables ActiveJDBC's default pluralization.
- **A BLOB column auto-expands into THREE columns.** Column `resume` (BLOB) generates `resume` (binary), `resume_fn` (filename), `resume_ft` (file type). Account for this in upload/download code — do NOT manually add the `_fn`/`_ft` columns.
- **Table naming:** simple single-feature apps may use a bare name matching the code (`todo` table + `todo` transaction). For multi-module apps, **prefix by group** to avoid clashes (`hr_employee`, `sales_order`). The model then becomes `Hr_employee` / `Sales_order` (first letter only capitalized). Do not invent prefixes when the golden template style (bare name) is enough.
- After altering schema **outside** the IDE, the developer must run **Introspect** to regenerate models. In-IDE schema changes regenerate automatically.

Supported column types: `VARCHAR`, `TEXT`, `MEDIUMTEXT`, `INT`, `BIGINT`, `BIT`, `DECIMAL`, `DATE`, `DATETIME`, `TIME`, `BLOB`, `MEDIUMBLOB`. (`VARCHAR` and `DECIMAL` take a length.)

## MySQL → Java type mapping

Use the right Java type with `.set()` and when reading values.

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

### BIT / checkboxes

- Store as `BIT`; ActiveJDBC maps to Java/Python **boolean**.
- **HTML checkbox:** only posts a value when checked. Unchecked → parameter missing/`None`.
- **Set from form:** `obj.set("done", r.getParameter("done") == "on")` — yields `True` if checked, `False` if not.
- **Query:** `Model.where("done = ?", False)` or `True` — use Python booleans, not `"0"`/`"1"` strings, unless you know the column is stored as INT.

So for a `DATETIME` column:
```python
from java.time import LocalDateTime
obj.set("created_date", LocalDateTime.now())
```

## Example

`db/migrations/001_create_contact.sql`:
```sql
CREATE TABLE contact (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    contact_no VARCHAR(20),
    email VARCHAR(100),
    created_date DATETIME,     -- default timestamp names; set in Python
    updated_date DATETIME
);
```
→ auto-generates model class `Contact`. An alter would be a new file, e.g. `db/migrations/002_alter_contact_add_company.sql`:
```sql
ALTER TABLE contact ADD COLUMN company VARCHAR(120);
```
