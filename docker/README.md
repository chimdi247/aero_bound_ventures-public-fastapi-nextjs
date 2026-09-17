# docker/

Supporting files for `docker compose up`, referenced from the root
`docker-compose.yml`.

## init-db/

Mounted into the `db` (PostgreSQL) container's
`/docker-entrypoint-initdb.d`. The official postgres image runs every
`*.sql` file it finds there, in alphabetical order, **once** -- only
when the container starts against a brand-new (empty) data volume.

| File | Purpose |
|---|---|
| `01-schema.sql` | Creates every table, transcribed directly from the app's actual Alembic baseline migration (`backend/alembic/versions/..._current_schema_baseline.py`), plus seeds the `alembic_version` bookkeeping row so future real migrations chain on top of this correctly. |
| `02-seed-admin-user.sql` | Seeds a super-admin login: `admin@example.com` / `password123`, replicating exactly what `python -m backend.manage create-super-user` does. |

### Why SQL instead of just running Alembic

The app already ships a `migrate` service (Alembic) in
`backend/compose.yaml`, kept here too under the `tools` profile for
when you add real schema changes later:

```bash
docker compose --profile tools run --rm migrate
```

But you asked for a SQL file that creates the schema on first boot, so
that's what runs by default here instead -- Alembic isn't run
automatically, to avoid it trying to create tables the SQL script
already created. The `alembic_version` row seeded in `01-schema.sql`
is what keeps those two paths compatible going forward.

### The seeded admin login

```
email:    admin@example.com
password: password123
```

This user is created exactly the way the app's own admin CLI creates
one: `is_superuser = true`, plus membership in an "Admins" group that
holds every permission in `ADMIN_PERMISSIONS`
(`backend/models/constants.py`) -- so both of the app's permission
check paths work for it.

The password hash is a real bcrypt hash (12 rounds, matching
`backend/utils/security.py`'s `hash_password()` -- passlib's
`CryptContext(schemes=["bcrypt"])` at its default cost). It was
pre-computed offline since plain SQL can't run passlib/bcrypt itself;
Python's bcrypt verifies it exactly like any hash it generated itself,
since it's the same algorithm.

### Resetting the database

These scripts only run once. If you've already started the stack
before (so the `db` volume already exists), editing the `.sql` files
won't do anything until you drop that volume:

```bash
docker compose down -v   # -v also removes named volumes, including the database
docker compose up --build
```
