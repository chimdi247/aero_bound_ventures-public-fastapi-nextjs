-- ============================================================
-- Seed a default super-admin login
-- ============================================================
--   email:    admin@example.com
--   password: password123
--
-- Replicates exactly what `python -m backend.manage create-super-user`
-- does (see backend/manage.py): create the user with is_superuser=true,
-- ensure the "Admins" group exists with the full ADMIN_PERMISSIONS set
-- from backend/models/constants.py, and add the user to that group --
-- so both permission-check paths (the is_superuser bypass and the
-- group/permission system) work for this login.
--
-- The password hash is a real bcrypt hash (12 rounds -- passlib's
-- CryptContext(schemes=["bcrypt"]) default cost, matching
-- backend/utils/security.py's hash_password() exactly). It's
-- pre-computed here since plain SQL can't run passlib/bcrypt itself.
--
-- Safe to re-run: every insert is a no-op if the row already exists.
-- ============================================================

-- 1. The 22 permissions from ADMIN_PERMISSIONS (backend/models/constants.py)
INSERT INTO permission (id, name, codename, description, created_at) VALUES
    ('61f820cd-c9bc-4bd7-aa59-33e58740433d', 'add_booking',    'bookings.add_booking',    'Add new bookings',      now()),
    ('e8728e16-9bcb-48be-8c16-2ed16de7f9de', 'view_booking',   'bookings.view_booking',   'View bookings',         now()),
    ('44c17bd0-352c-46ff-ba31-af82703342da', 'change_booking', 'bookings.change_booking', 'Change bookings',       now()),
    ('bcaed723-c9e2-4421-bd9b-faa3deab4e50', 'delete_booking', 'bookings.delete_booking', 'Delete bookings',       now()),
    ('f103b5ee-475a-4aee-8855-8c5b51cca426', 'add_user',       'users.add_user',          'Add new users',         now()),
    ('666a86b8-9548-43e1-adc5-03c31034e382', 'view_user',      'users.view_user',         'View users',            now()),
    ('85748436-5852-419f-b516-7067d6ce7e1b', 'change_user',    'users.change_user',       'Change users',          now()),
    ('2170c13c-99e0-49f9-b73b-32a3396aa56a', 'delete_user',    'users.delete_user',       'Delete users',          now()),
    ('93002255-8e44-4170-9ad2-96596c55d6be', 'add_flight',     'flights.add_flight',      'Add new flights',       now()),
    ('4c845a93-4261-4400-b6a1-73e823171e01', 'view_flight',    'flights.view_flight',     'View flights',         now()),
    ('8e2e8026-a8c5-4d15-960b-237132e526f5', 'change_flight',  'flights.change_flight',   'Change flights',        now()),
    ('54da6d13-e2b8-410c-b137-ad70f3378f85', 'delete_flight',  'flights.delete_flight',   'Delete flights',        now()),
    ('32ce1d86-4c12-4b8d-90e6-bb8295ca5e54', 'add_payment',    'payments.add_payment',    'Add new payments',      now()),
    ('0e682fc2-4d26-418c-86a3-4819d0d266b7', 'view_payment',   'payments.view_payment',   'View payments',         now()),
    ('1097c01f-5d32-45e2-ab4a-9ccd1a60e2e8', 'change_payment', 'payments.change_payment', 'Change payments',       now()),
    ('0bd0e7b2-44a7-4728-a204-2ea439f36bab', 'delete_payment', 'payments.delete_payment', 'Delete payments',       now()),
    ('f24384aa-d539-4559-aa20-01c94b5b033a', 'add_ticket',     'tickets.add_ticket',      'Add new tickets',       now()),
    ('1fcd9c62-9e2e-42d7-b674-de245681ef96', 'view_ticket',    'tickets.view_ticket',     'View tickets',          now()),
    ('179a53b1-cb96-4073-b748-e4b8d52d0ebf', 'change_ticket',  'tickets.change_ticket',   'Change tickets',        now()),
    ('7f517fd4-b1af-4400-a95a-e5e0ef4ba5f7', 'delete_ticket',  'tickets.delete_ticket',   'Delete tickets',        now()),
    ('bce9132e-66a7-465d-9b5f-561321f1ccdc', 'view_stats',     'admin.view_stats',        'View system statistics', now()),
    ('8d1aaa47-f8ac-403e-b892-7f10d83bc18c', 'view_dashboard', 'admin.view_dashboard',    'View admin dashboard', now())
ON CONFLICT (codename) DO NOTHING;

-- 2. The "Admins" group
INSERT INTO "group" (id, name, description, created_at)
VALUES (
    '213abf84-b405-45f8-b92b-ec3a5b1829bc',
    'Admins',
    'Administrator group with full system permissions',
    now()
)
ON CONFLICT (name) DO NOTHING;

-- 3. Link every admin permission to the Admins group
INSERT INTO grouppermission (id, group_id, permission_id, assigned_at)
SELECT gen_random_uuid(), g.id, p.id, now()
FROM "group" g
CROSS JOIN permission p
WHERE g.name = 'Admins'
  AND p.codename IN (
    'bookings.add_booking', 'bookings.view_booking', 'bookings.change_booking', 'bookings.delete_booking',
    'users.add_user', 'users.view_user', 'users.change_user', 'users.delete_user',
    'flights.add_flight', 'flights.view_flight', 'flights.change_flight', 'flights.delete_flight',
    'payments.add_payment', 'payments.view_payment', 'payments.change_payment', 'payments.delete_payment',
    'tickets.add_ticket', 'tickets.view_ticket', 'tickets.change_ticket', 'tickets.delete_ticket',
    'admin.view_stats', 'admin.view_dashboard'
  )
  AND NOT EXISTS (
    SELECT 1 FROM grouppermission gp
    WHERE gp.group_id = g.id AND gp.permission_id = p.id
  );

-- 4. The admin user itself (bcrypt hash of "password123", 12 rounds)
INSERT INTO userindb (id, email, password, google_id, auth_provider, is_active, is_superuser)
VALUES (
    '4d7c5141-dba1-45b6-9f44-a094248fc363',
    'admin@example.com',
    '$2b$12$jtEpKQNb33HCXbVe5oP9/u3XGVBigk7lBYdyrMNj7P77HD3Vt/l0m',
    NULL,
    'email',
    true,
    true
)
ON CONFLICT (email) DO NOTHING;

-- 5. Add the admin user to the Admins group
INSERT INTO usergroup (id, user_id, group_id, assigned_at)
SELECT gen_random_uuid(), u.id, g.id, now()
FROM userindb u
CROSS JOIN "group" g
WHERE u.email = 'admin@example.com'
  AND g.name = 'Admins'
  AND NOT EXISTS (
    SELECT 1 FROM usergroup ug
    WHERE ug.user_id = u.id AND ug.group_id = g.id
  );
