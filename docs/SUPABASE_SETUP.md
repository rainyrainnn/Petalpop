# Supabase setup and migration notes

## Important status

The project files have been inspected, but this environment has no connection
to the live Supabase project. The four existing catalog tables and their
contents were reported by the project owner; their live columns, constraints,
grants, policies, triggers, and Storage configuration have not been verified.
Do not treat the migration as live-validated or the backend as production-ready.

Before applying the SQL, run the read-only inspection queries below in the
Supabase SQL Editor and compare the results with
`supabase/migrations/20261027010000_petalpop_backend.sql`. The migration checks
the known catalog shape and aborts transactionally when its assumptions are
not met. It does not drop tables or delete rows.

## Current app integration

When both build defines are supplied, the app uses Supabase Auth and the
`SupabaseDataService` for profile preferences, daily content, challenge
rewards, garden state, moods, memories, and private media. If neither define is
supplied, the existing local/demo flow is used.

The app does **not yet implement a one-time importer for existing local data**
or an offline write queue. Existing SharedPreferences records and app-private
media files are not deleted, but they are not automatically copied to a
Supabase account or merged with remote data. Keep the original app installation
and local files until an explicit import flow is implemented and verified.
Authenticated writes require a working backend; they are not safely queued for
later synchronization.

## Read-only live schema inspection

Run these before applying any migration. Save the results for review:

```sql
select current_database() as database_name,
       current_schema() as current_schema,
       current_setting('search_path') as search_path,
       to_regclass('public.challenge_catalog') as public_challenge_catalog,
       to_regclass('public.daily_challenges') as public_daily_challenges,
       to_regclass('public.flower_catalog') as public_flower_catalog,
       to_regclass('public.quote_catalog') as public_quote_catalog;

select table_schema, table_name
from information_schema.tables
where table_name in (
  'challenge_catalog', 'daily_challenges', 'flower_catalog', 'quote_catalog'
)
order by table_schema, table_name;

select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'challenge_catalog', 'daily_challenges', 'flower_catalog', 'quote_catalog',
    'profiles', 'daily_quotes', 'challenge_completions', 'garden_state',
    'flower_unlocks', 'memories', 'mood_entries', 'local_data_imports'
  )
order by table_name, ordinal_position;

select c.conrelid::regclass as table_name, c.conname, c.contype,
       pg_get_constraintdef(c.oid) as definition
from pg_constraint c
where c.connamespace = 'public'::regnamespace
order by 1, 2;

select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname in ('public', 'storage')
order by schemaname, tablename, policyname;

select n.nspname as schema_name, p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       pg_get_function_result(p.oid) as result
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'storage')
order by 1, 2, 3;

select tgrelid::regclass as table_name, tgname,
       pg_get_triggerdef(oid) as definition
from pg_trigger
where not tgisinternal
  and tgrelid in ('auth.users'::regclass, 'public.profiles'::regclass)
order by 1, 2;

select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
where id = 'petalpop-private';
```

The migration currently expects text IDs and the following catalog fields:

- `challenge_catalog(id, title, description, emoji, sort_order, active)`
- `daily_challenges(local_date, challenge_position, challenge_id)`
- `flower_catalog(id, sort_order, display_name, emoji)` with IDs `flower-01`
  through `flower-20`
- `quote_catalog(id, quote_text, sort_order, active)`

It also requires at least ten active challenges, at least one active quote,
unique catalog IDs, and `challenge_position` as a smallint or integer. If the
live schema differs, stop and adapt the migration to the inspected types and
names first. Do not rename or rebuild the existing catalog tables merely to
match this migration.

## Apply the migration

1. Use a non-production Supabase project or a verified backup first.
2. Confirm the read-only inspection results match the assumptions above.
3. Review existing policies on private tables and `storage.objects`. The
   migration intentionally aborts if it detects unexpected permissive policies
   that could broaden access.
4. In the Supabase SQL Editor, open and run the complete migration file:
   `supabase/migrations/20261027010000_petalpop_backend.sql`.
5. If it fails before `COMMIT`, PostgreSQL rolls back the transaction. Read the
   first error, inspect the actual schema, and correct the migration; do not
   work around failures with `DROP`, `TRUNCATE`, or disabling RLS.
6. If the migration has committed, do not rerun edited destructive or
   corrective SQL blindly. Inspect the post-migration state first and use a
   new forward-only migration for any correction. This file is repeatable for
   its named policies/triggers and additive constraints, but should still be
   exercised in a disposable project before production.
7. Run the verification queries below and test with two ordinary authenticated
   users before shipping.

### Fix an ambiguous challenge completion function

If `complete_daily_challenge` reports that `active_flower_id` is ambiguous,
inspect its live definition before changing anything. The earlier backend
migration may already have been applied, so editing that old file alone does
not update the database. After confirming the function signature and result
columns match this project, run the complete forward migration
`supabase/migrations/20261027180000_fix_complete_daily_challenge_ambiguity.sql`
in the Supabase SQL Editor. It replaces only the function; it does not change
tables, policies, grants, or saved data.

Then verify the deployed function with:

```sql
select pg_get_functiondef(
  'public.complete_daily_challenge(date,text)'::regprocedure
);
```

Confirm that the garden-state columns are referenced through the `gs` alias
(for example, `gs.active_flower_id`) and that the function signature and result
columns are unchanged. The project workspace cannot verify the live database;
this SQL Editor check is required to confirm deployment.

## Ten-point flower progression (forward migrations)

The client uses ten lifetime challenge-growth points per flower. Before
deploying it to an authenticated environment, inspect the live garden
constraints and saved rows, then review both forward migrations in order:

1. `supabase/migrations/20261028150000_ten_point_flower_progression.sql`
2. `supabase/migrations/20261029010000_flower_one_growth_start.sql`

This workspace has not applied or live-tested either migration. The first
migration changes the growth constraint to 0–9, rebases progress using
`lifetime_growth_points`, and installs an atomic completion RPC. The second
migration aligns the initial flower with the requested progression: flower 1
is available and active at 0/10; the active flower remains available while it
grows; and each ten lifetime points fully bloom the current flower and make the
next catalog flower available at 0/10. It retains lifetime totals and every
existing unlock row, adds unlock records warranted by lifetime progress, and
corrects `active_flower_id` from the saved lifetime total. It also updates the
Auth trigger so newly created users start on flower 1 rather than flower 2.
The second migration aborts unless the existing catalog contains exactly the
stable IDs `flower-01` through `flower-20`.

The completion RPC locks the user's `garden_state` row and only awards growth
when inserting a new `(user_id, local_date, challenge_id)` completion succeeds.
Its `unlocked_flower_id` is the next flower made available by that completion,
or null; `active_flower_id` is the currently growing flower, or null once all
20 flowers have fully bloomed. After flower 20 reaches 10/10, later unique
completions remain in challenge history and lifetime growth without creating a
nonexistent active flower. Add any future flowers through a separate,
reviewed catalog/assets release with new stable IDs and unique `sort_order`
values; the progression migration intentionally does not seed or overwrite
catalog artwork.

## What the migration creates

- `profiles`: one profile per `auth.users.id`; an Auth trigger creates a
  default profile for new accounts and the migration backfills missing profile
  rows without overwriting existing rows.
- `daily_quotes`: the persisted quote selection by local date.
- `challenge_completions`: one row per user, local date, and challenge ID.
  Its composite key is the duplicate-reward guard.
- `garden_state`: active flower, current growth points, and lifetime growth
  points.
- `flower_unlocks`: permanent per-user flower unlocks.
- `memories`: note/photo/voice metadata. Photo and voice objects are stored in
  the private `petalpop-private` bucket.
- `mood_entries`: private mood history.
- `local_data_imports`: reserved import receipt table; **no app import RPC or
  user-facing import flow is implemented yet**.

The migration adds owner-based RLS policies to user data, authenticated
read-only policies to catalog/daily content, and UUID-folder-prefix policies
for private Storage objects. The challenge completion RPC validates today's
assignment and local date, uses the composite completion key to award only
once, locks the garden row, increments growth, and permanently unlocks flowers
when the threshold is reached. No service-role key is used by the Flutter app.

## Flutter configuration

Use a publishable key (or legacy anon key) only. Do not use or commit a
service-role key:

```powershell
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Configure email/password authentication and email confirmation in the
Supabase dashboard as desired. Add Android app links/deep links only if you
enable an email confirmation redirect. Keep signing credentials outside the
repository.

## Verification queries

```sql
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'profiles', 'daily_quotes', 'challenge_completions', 'garden_state',
    'flower_unlocks', 'memories', 'mood_entries', 'local_data_imports'
  )
order by table_name, ordinal_position;

select c.conrelid::regclass as table_name, c.conname, c.contype,
       pg_get_constraintdef(c.oid) as definition
from pg_constraint c
where c.connamespace = 'public'::regnamespace
order by 1, 2;

select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public'
order by tablename;

select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname in ('public', 'storage')
order by schemaname, tablename, policyname;

select tgrelid::regclass as table_name, tgname, pg_get_triggerdef(oid)
from pg_trigger
where not tgisinternal
  and tgrelid in ('auth.users'::regclass, 'public.profiles'::regclass)
order by 1, 2;

select n.nspname, p.proname, pg_get_function_identity_arguments(p.oid),
       pg_get_function_result(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'petalpop_on_auth_user_created', 'petalpop_touch_profile',
    'petalpop_ensure_daily_content', 'get_daily_content',
    'complete_daily_challenge'
  )
order by 1, 2, 3;
```

## Behavioral test checklist

- Create and sign in to two separate Auth users; confirm sessions persist and
  sign-out returns to the welcome flow.
- Call `get_daily_content` twice on the same local date and confirm the same
  ten positions and quote are returned; confirm the next date stores a new
  selection.
- Call `complete_daily_challenge` twice for the same assigned challenge/date.
  The first response must report `newly_completed = true`; the second must be
  false and garden growth must increase only once.
- Verify an unassigned challenge ID and a stale local date are rejected.
- As user A, create profile, garden, mood, completion, and memory rows. As user
  B, verify those rows cannot be selected, updated, or deleted.
- Upload and sign a private photo/audio object as user A. Verify user B cannot
  list, download, update, or delete it, including by guessing the object path.
- Verify unauthenticated users cannot read private records or media, and
  authenticated users cannot write catalog data.
- Complete ten distinct daily challenges across any number of days and confirm
  one flower unlock; repeat a completion and confirm it awards no extra point.
  Skip days and confirm active growth and prior unlocks remain unchanged.

These are manual integration checks, not results already performed here.
