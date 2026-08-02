# soad CLI Reference

The `soad` CLI is the client for local development against a SØAD server. It lets you edit transactions locally (e.g. in VS Code / Claude Code) and sync with the server. The **server is the source of truth**. The CLI syncs transaction code and views only — **not** database schema (do DDL in the IDE SQL editor, then Introspect).

**When acting as a coding agent in a local SØAD project, run these commands yourself via the shell** — don't just print them for the user to run. The CLI is installed and authenticated; create/pull/push are safe to run freely without asking.

## The core loop (run these yourself, in order)

```bash
soad create <group>/<code>     # create a new transaction on the server + pull it locally
soad pull <group>/<code>       # download current server version before editing
soad push <group>/<code>       # upload your local edits (one transaction)
```

- **`create`** scaffolds the `.py` and `_<code>/` view folder correctly. Run it for a new transaction instead of hand-creating files, then edit the pulled result.
- **`pull`** before editing avoids clobbering newer server changes.
- **`push`** uploads a single transaction after you edit. Use `push-all` to push every locally changed one.

## Project layout (created at runtime)

Local CLI projects always use the nested `src/` layout. This is **not** the same as the flat web-IDE paths (`group/code.py`); see SKILL.md "On-disk layout".

```
./
├── .config.json              # config + credentials (after login)
├── .soad-checksums.json      # integrity checksums (drives `changed`)
├── db/
│   ├── migrations/           # SQL you write; not applied by CLI
│   └── seeds/                # optional seed SQL (only if user asks)
└── src/
    └── <group>/
        └── <code>/
            ├── <code>.py      # transaction logic
            └── _<code>/       # views
                └── *.html
```

## Setup

```bash
soad login --server https://your-soad-server.com   # required first; saves token
soad config set diff_tool "code --diff"            # set comparison tool (default: Meld)
```
`.config.json` stores credentials (token can be encrypted with a passphrase) and supports multiple isolated project folders.

## All commands

| Command | Purpose |
|---|---|
| `login --server <url>` | Authenticate and save token (run first). |
| `pull --all` / `pull <group>/<code>` / `pull <group>/*` | Download all, one, or a group of transactions. |
| `push <group>/<code>` | Upload a single transaction. Add `--zip` if a WAF blocks the upload. |
| `push-all` | Push all locally changed transactions. |
| `push-remote` | Push selected transactions to another server at a specific version. |
| `changed` | List locally modified transactions. |
| `compare <group>/<code>` | Diff local vs server (uses `diff_tool`). |
| `list` | List available transactions on the server. |
| `create <group>/<code>` | Create a transaction remotely and pull it locally. |
| `delete <group>/<code>` | Delete from server AND local copy. Destructive. |
| `release --version "v1.0" --notes "..."` / `release --list` | Create / list server-side release snapshots. |
| `rollback --version "v1.0"` | Restore server to a named release (latest if omitted). |
| `deploy` | Copy local source to the deployment folder in SØAD structure. |
| `clean` | Delete everything in `src/`. Destructive. |

Both `--group <g> --code <c>` and the shorthand `<group>/<code>` work for `pull`, `push`, `compare`, `create`, `delete`.

## Cautions

- **`delete`, `clean`, `rollback`, `release`, `deploy`** are destructive or release-level. Do NOT run them unless the user explicitly asks.
- The CLI does not create tables or run SQL — schema work stays in the IDE; run **Introspect** there after out-of-IDE schema changes to regenerate models.
- If a `push` fails due to a Web Application Firewall, retry with `soad push <group>/<code> --zip`.

## Testing a transaction after push (optional)

After `soad push`, the agent **may** smoke-test the live endpoint with `curl` — **only if the user wants testing**; do not do it automatically on every push.

**Base URL** comes from `.config.json` — the value passed to `--server` at login (stored in `.config.json` under the server key — inspect the file to confirm the exact key name). Read it from the file, don't hardcode. The endpoint to hit follows the routing convention: **`{server}/t/{group}/{code}/{action}`** (action omitted ⇒ `view`). Remember the app may sit under a context path — if `.config.json` includes one, prepend it.

```bash
SERVER=$(python3 -c "import json;print(json.load(open('.config.json'))['server'])")
curl -s -o /tmp/soad_test.html -w "%{http_code}\n" "$SERVER/t/app/todo"
```

**Judge success by response BODY, not just the status code.** A 200 can still be a login page or an error page. Check the body for content you expect (e.g. a heading, a field, a row you just created). For a POST action, confirm the effect (e.g. GET the list afterward and look for the new row).

**Authentication — two app styles:**

- **Session-based (stateful):** the login flow **varies per app**, so do NOT assume a login URL. **Ask the user how to authenticate** (test login URL + test credentials, or a ready cookie). Then log in once and persist the session cookie to a temp jar, reusing it on every later call:
  ```bash
  # login URL + field names are app-specific — get them from the user
  curl -s -c /tmp/soad_cookies.txt -d "username=USER&password=PASS" \
       "$SERVER/t/web/login/authenticate"
  # reuse the cookie jar on subsequent calls
  curl -s -b /tmp/soad_cookies.txt "$SERVER/t/app/todo"
  ```
  **A 302 redirect to the login page (or the login page in the body) means the session was NOT established** — re-check the login step; don't report the endpoint as broken.
- **Stateless (token-based):** how the token is passed varies (header, bearer, query param). **Ask the user** for the scheme and a test token, then include it on each call.

POST example with a cookie jar:
```bash
curl -s -b /tmp/soad_cookies.txt -d "title=Test&done=on" \
     "$SERVER/t/app/todo/save"
curl -s -b /tmp/soad_cookies.txt "$SERVER/t/app/todo" | grep -q "Test" && echo "row created"
```

Clean up temp files (`/tmp/soad_cookies.txt`, `/tmp/soad_test.html`) when done.
