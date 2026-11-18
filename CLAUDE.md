# Lab 4 — Users, Privileges and Roles (Workshop #4, case 14 "La Sabana")

## Goal

- Solve `activity.md` (tasks 1-17 + presentation question) **exactly as stated**. Deliverables: one SQL*Plus script, a report with steps and results, and a live run during the presentation.
- The script is reviewed by the professor on a **Windows Server VM with native SQL*Plus**, Oracle version unknown (>= 12c: lab 2 used `FETCH FIRST` without complaints). It must run there unchanged and in this devcontainer.
- `team-advance.md` is a teammate's manual walkthrough of tasks 1-14 (SQL Developer/DBeaver). Use it as a reference, not as verified truth (e.g. its task 4 privilege list omits CREATE TABLE).

## Environment (devcontainer, verified 2026-11-17)

- Compose project `lab4-admin-db`, file `.devcontainer/docker-compose.yml`:
  - `oracle`: image from `ORACLE_IMAGE`, default `gvenzl/oracle-free:23.26.4-slim-faststart` (banner says "26ai", release 23.x). Only `ORACLE_PASSWORD` (SYS/SYSTEM) is set; **no app user is pre-created on purpose**: the script must create everything starting from SYSTEM, as on the professor's machine.
  - `app`: built from `.devcontainer/Dockerfile` (Ubuntu 24.04 + Instant Client + SQL*Plus 23 + rlwrap). `network_mode: service:oracle`, so `localhost:1521` is the DB inside and outside the container. Env `ORACLE_CONN=localhost:1521/<service>`.
- Versions (one runs at a time; each has its own volume `lab4-oracle-<ver>`):

  | Version | `ORACLE_IMAGE` | `ORACLE_SERVICE` | `ORACLE_VOLUME` |
  |---|---|---|---|
  | 23ai (default, presentation) | `gvenzl/oracle-free:23.26.4-slim-faststart` | `FREEPDB1` | `23` |
  | 21c XE | `gvenzl/oracle-xe:21.3.0-slim-faststart` | `XEPDB1` | `21` |
  | 18c XE (19c proxy, same 12.2 family) | `gvenzl/oracle-xe:18.4.0-slim-faststart` | `XEPDB1` | `18` |

  All three verified with SQL*Plus 23 from `app`. 21c/18c images are amd64 only.
- Switch versions without editing `.env`: `export ORACLE_IMAGE=... ORACLE_SERVICE=... ORACLE_VOLUME=...` then `docker compose -f .devcontainer/docker-compose.yml up -d`; `unset` them and `up -d` again to return to 23ai.
- Run SQL from the host (the host `sql` binary is GNU parallel, not SQLcl; never use it):

```bash
F=.devcontainer/docker-compose.yml
PW=$(grep '^ORACLE_PASSWORD=' .devcontainer/.env | cut -d= -f2-)
docker compose -f $F exec -T -e PW="$PW" app bash -c 'sqlplus -s -L "system/$PW@$ORACLE_CONN" @/workspace/<script>.sql'
```

- The solution script `workshop4_la_sabana.sql` connects by itself and reads the SYSTEM password with `ACCEPT`, so run it with `/nolog` and feed the password on stdin:

```bash
printf '%s\n' "$PW" | docker compose -f $F exec -T app bash -c 'sqlplus -L /nolog @/workspace/workshop4_la_sabana.sql'
```

- On 21c/18c, copy a modified version into the container instead of editing the script: `sed 's#/FREEPDB1#/XEPDB1#' workshop4_la_sabana.sql | docker compose -f $F exec -T app bash -c 'cat > /tmp/xe.sql'`, then run `@/tmp/xe.sql` the same way.
- Expected result on every version: exit 0, exactly 5 `ORA-` lines (3x ORA-01031, ORA-00993, ORA-01939), identical output on a second run.

- `.devcontainer/.env` is gitignored; never print or commit passwords. `down -v` destroys the active version's data: ask first.
- VS Code extension `oracle.sql-developer` is for the step-by-step presentation only; the script is validated with SQL*Plus.

## Script rules (portability decisions)

- Write for **19c**, test on 23ai, 21c and 18c. No version conditionals (`DBMS_DB_VERSION` branches were rejected: duplicate paths, harder to explain live).
- Forbidden 23ai-only features: `DROP/CREATE ... IF [NOT] EXISTS`, schema-level privileges, `DB_DEVELOPER_ROLE`, SQL*Plus `SET ERRORDETAILS`.
- Connection in one place: `DEFINE conn = localhost:1521/FREEPDB1` at the top; every `CONNECT user/pwd@&conn` uses it. SYSTEM password via `ACCEPT ... HIDE`, never hardcoded.
- Always connect to the PDB. In the CDB root `CREATE USER` fails with ORA-65096 (common users need `C##`). Do not use the `_ORACLE_SCRIPT` hack.
- Re-runnable cleanup: PL/SQL blocks with `EXECUTE IMMEDIATE` and an exception handler that ignores only the "does not exist" code (ORA-01918 user, ORA-01919 role) and re-raises anything else.
- Expected failures (tasks 11, 17, etc.): same pattern as lab 2, which the professor accepted: `WHENEVER SQLERROR CONTINUE`, then a comment with the real `ORA-` code and the explanation. Only document codes observed in real runs.
- ASCII only (no accents or n-tilde, even in comments): SQL*Plus on Windows may use a different `NLS_LANG`.
- 23ai output adds `Help: https://docs.oracle.com/error-help/...` lines to errors; the professor's output will not have them. Cosmetic only.

## Oracle behavior verified or relied upon

- Revoking a **privilege from a role** takes effect immediately, even in open sessions. Revoking a **role from a user** (tasks 5, 15) only applies to new sessions or after `SET ROLE`. Each SQL*Plus `CONNECT` opens a new session; extension connections must be reconnected after a role revoke.
- `CREATE SESSION` is not part of `rol_admin_local`: grant it directly. A user holding the role `WITH ADMIN OPTION` can grant the role, not privileges outside it (teammate saw ORA-01031 granting CREATE SESSION as admin_teusaquillo).
- `admin_sabanero` needs `CREATE ROLE`, `CREATE USER` and the system privileges it grants to the role `WITH ADMIN OPTION` (or `GRANT ANY PRIVILEGE`).
- Users that create tables with rows need a tablespace quota (`QUOTA ... ON users`).
- Revoking a role does not cascade, even if it was granted `WITH ADMIN OPTION` (task 16: admin_usaquen keeps rol_auditor). Revoking an object privilege granted `WITH GRANT OPTION` does cascade to whoever received it through the grantee (task 17).
- A user holding a role `WITH ADMIN OPTION` can revoke it from anyone, even its creator (admin_teusaquillo ran `REVOKE rol_admin_local FROM admin_sabanero`, tested on 23ai).
- Mismatched options: `WITH ADMIN OPTION` on an object privilege -> ORA-00993 `missing GRANT keyword`; `WITH GRANT OPTION` on a system privilege -> ORA-01939, whose text differs by version (18c/21c: `only the ADMIN OPTION can be specified`; 23ai: `invalid option specified for WITH clause in the GRANT statement`); `WITH GRANT OPTION` to a role -> ORA-01926.

## Report (lab 5)

- Source of truth: `docs/informe-lab5.md` (Spanish). Deliverable: `docs/informe-lab5.odt`, transcribed from the md, using the lab 4 Word report (`docs/Informe_Diagnostico_Laboratio_Bloque_4.docx`) as the template.
- Fonts: Noto Sans for text, Noto Sans Mono for code, embedded in the ODT. The Word template's Aptos font is not installed, and LibreOffice imports it as a serif font; never reintroduce Aptos, Calibri or Consolas.
- Code styles (dark terminal look): paragraph `Codigo` for SQL*Plus blocks (one paragraph per block, line breaks inside); character styles `Codigo en linea` (inline code), `Terminal comando` (`SQL>` and continuation lines), `Terminal error` (`ERROR at line` and `ORA-` lines).
- Edit the ODT with scripts (unzip, modify XML, rezip with `mimetype` stored first), then round-trip it through `soffice --headless --convert-to odt` so fonts stay embedded; check the result by exporting to PDF.

## Working conventions

- Verify against the database or Oracle docs before stating behavior; never fabricate output.
- Short answers; one question at a time; artifacts in English unless asked otherwise.
- Git: local repo on `main`, no remote. Conventional Commits, no AI attribution. `.atl/` (tooling cache) is gitignored.
