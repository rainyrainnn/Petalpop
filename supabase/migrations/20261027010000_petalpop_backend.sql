begin;

-- Catalog tables already exist in this project. Validate their shape and IDs;
-- never recreate, seed over, or rewrite catalog data here.
do $$
declare
  v_table text;
  v_column text;
begin
  for v_table, v_column in
    select * from (values
      ('challenge_catalog', 'id'),
      ('challenge_catalog', 'title'),
      ('challenge_catalog', 'description'),
      ('challenge_catalog', 'emoji'),
      ('challenge_catalog', 'sort_order'),
      ('challenge_catalog', 'active'),
      ('quote_catalog', 'id'),
      ('quote_catalog', 'quote_text'),
      ('quote_catalog', 'sort_order'),
      ('quote_catalog', 'active'),
      ('flower_catalog', 'id'),
      ('flower_catalog', 'sort_order'),
      ('flower_catalog', 'display_name'),
      ('flower_catalog', 'emoji'),
      ('daily_challenges', 'local_date'),
      ('daily_challenges', 'challenge_position'),
      ('daily_challenges', 'challenge_id')
    ) as required(table_name, column_name)
  loop
    if to_regclass(format('public.%I', v_table)) is null then
      raise exception
        'Required existing catalog table public.% is missing; migration stopped without creating dependent tables.',
        v_table;
    end if;
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = v_table
        and column_name = v_column
    ) then
      raise exception
        'Existing public.% is missing expected column "%"; inspect the live schema and adapt this migration before retrying.',
        v_table, v_column;
    end if;
  end loop;

  if exists (
    select 1
    from (values
      ('challenge_catalog', 'id', array['text']::text[]),
      ('challenge_catalog', 'title', array['text', 'character varying']::text[]),
      ('challenge_catalog', 'description', array['text', 'character varying']::text[]),
      ('challenge_catalog', 'emoji', array['text', 'character varying']::text[]),
      ('challenge_catalog', 'active', array['boolean']::text[]),
      ('quote_catalog', 'id', array['text']::text[]),
      ('quote_catalog', 'quote_text', array['text', 'character varying']::text[]),
      ('quote_catalog', 'active', array['boolean']::text[]),
      ('flower_catalog', 'id', array['text']::text[]),
      ('flower_catalog', 'display_name', array['text', 'character varying']::text[]),
      ('flower_catalog', 'emoji', array['text', 'character varying']::text[]),
      ('daily_challenges', 'local_date', array['date']::text[]),
      ('daily_challenges', 'challenge_id', array['text']::text[])
    ) as expected(table_name, column_name, allowed_types)
    join information_schema.columns c
      on c.table_schema = 'public'
     and c.table_name = expected.table_name
     and c.column_name = expected.column_name
    where not c.data_type = any(expected.allowed_types)
  ) then
    raise exception
      'An existing catalog column has an unsupported type; inspect information_schema.columns and adapt the migration before retrying.';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name in ('challenge_catalog', 'quote_catalog', 'flower_catalog')
      and column_name = 'sort_order'
      and data_type not in ('smallint', 'integer', 'bigint')
  ) or exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'daily_challenges'
      and column_name = 'challenge_position'
      and data_type not in ('smallint', 'integer')
  ) then
    raise exception
      'An existing catalog ordering column has an unsupported type; inspect information_schema.columns and adapt the migration before retrying.';
  end if;

  if exists (
    select 1 from public.challenge_catalog
    where id is null or title is null or description is null or emoji is null
      or sort_order is null or active is null
  ) then
    raise exception 'challenge_catalog contains null values in required fields';
  end if;
  if exists (
    select 1 from public.quote_catalog
    where id is null or quote_text is null or sort_order is null or active is null
  ) then
    raise exception 'quote_catalog contains null values in required fields';
  end if;
  if exists (
    select 1 from public.flower_catalog
    where id is null or sort_order is null
      or display_name is null or emoji is null
  ) then
    raise exception 'flower_catalog contains null values in required fields';
  end if;
  if exists (
    select 1 from public.daily_challenges
    where local_date is null or challenge_position is null or challenge_id is null
  ) then
    raise exception 'daily_challenges contains null assignment fields';
  end if;
  if exists (
    select 1
    from public.daily_challenges
    group by local_date, challenge_id
    having count(*) > 1
  ) then
    raise exception
      'daily_challenges has duplicate (local_date, challenge_id) assignments; resolve duplicates without deleting user data before retrying.';
  end if;
  if exists (
    select 1 from public.daily_challenges dc
    left join public.challenge_catalog cc on cc.id = dc.challenge_id
    where cc.id is null
  ) then
    raise exception 'daily_challenges contains challenge IDs absent from challenge_catalog';
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.challenge_catalog'::regclass
      and contype in ('p', 'u')
      and conkey = array[
        (select attnum from pg_attribute
         where attrelid = 'public.challenge_catalog'::regclass
           and attname = 'id')
      ]::smallint[]
  ) then
    raise exception 'challenge_catalog.id must be a primary or unique key';
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.quote_catalog'::regclass
      and contype in ('p', 'u')
      and conkey = array[
        (select attnum from pg_attribute
         where attrelid = 'public.quote_catalog'::regclass
           and attname = 'id')
      ]::smallint[]
  ) then
    raise exception 'quote_catalog.id must be a primary or unique key';
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.flower_catalog'::regclass
      and contype in ('p', 'u')
      and conkey = array[
        (select attnum from pg_attribute
         where attrelid = 'public.flower_catalog'::regclass
           and attname = 'id')
      ]::smallint[]
  ) then
    raise exception 'flower_catalog.id must be a primary or unique key';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.daily_challenges'::regclass
      and contype = 'u'
      and conkey = array[
        (select attnum from pg_attribute
         where attrelid = 'public.daily_challenges'::regclass
           and attname = 'local_date'),
        (select attnum from pg_attribute
         where attrelid = 'public.daily_challenges'::regclass
           and attname = 'challenge_id')
      ]::smallint[]
  ) then
    alter table public.daily_challenges
      add constraint daily_challenges_date_challenge_key
      unique (local_date, challenge_id);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.daily_challenges'::regclass
    and contype = 'f'
    and confrelid = 'public.challenge_catalog'::regclass
    and conkey = array[
      (select attnum from pg_attribute
       where attrelid = 'public.daily_challenges'::regclass
         and attname = 'challenge_id')
    ]::smallint[]
  ) then
    alter table public.daily_challenges
    add constraint daily_challenges_challenge_id_fkey
    foreign key (challenge_id) references public.challenge_catalog(id);
  end if;
end;
$$;

-- Create a missing application table; if a prior partial migration created it,
-- validate its columns rather than silently accepting an incompatible shape.
do $$
declare
  v_table text;
  v_columns text[];
  v_column text;
begin
  for v_table, v_columns in
    select * from (values
      ('profiles', array['id','display_name','avatar_id','theme','time_zone','created_at','updated_at']::text[]),
      ('daily_quotes', array['local_date','quote_id']::text[]),
      ('challenge_completions', array['user_id','local_date','challenge_id','completed_at']::text[]),
      ('garden_state', array['user_id','active_flower_id','growth_points','lifetime_growth_points','updated_at']::text[]),
      ('flower_unlocks', array['user_id','flower_id','unlocked_at']::text[]),
      ('memories', array['id','user_id','type','title','description','created_at','storage_path','duration_seconds']::text[]),
      ('mood_entries', array['id','user_id','mood','emoji','note','created_at']::text[]),
      ('local_data_imports', array['user_id','imported_at','source_install_id','summary']::text[])
    ) as expected(table_name, columns)
  loop
    if to_regclass(format('public.%I', v_table)) is not null then
      foreach v_column in array v_columns loop
        if not exists (
          select 1 from information_schema.columns
          where table_schema = 'public'
            and table_name = v_table
            and column_name = v_column
        ) then
          raise exception
            'Existing public.% is missing column "%"; migration stopped for manual schema review.',
            v_table, v_column;
        end if;
      end loop;
    else
      case v_table
        when 'profiles' then
          execute $ddl$
            create table public.profiles (
              id uuid primary key references auth.users(id) on delete cascade,
              display_name text not null default 'Sunshine'
                check (length(trim(display_name)) between 1 and 80),
              avatar_id text not null default 'girl',
              theme text not null default 'light'
                check (theme in ('light', 'dark')),
              time_zone text not null default 'UTC',
              created_at timestamptz not null default now(),
              updated_at timestamptz not null default now()
            )
          $ddl$;
        when 'daily_quotes' then
          execute $ddl$
            create table public.daily_quotes (
              local_date date primary key,
              quote_id text not null references public.quote_catalog(id)
            )
          $ddl$;
        when 'challenge_completions' then
          execute $ddl$
            create table public.challenge_completions (
              user_id uuid not null references auth.users(id) on delete cascade,
              local_date date not null,
              challenge_id text not null,
              completed_at timestamptz not null default now(),
              primary key (user_id, local_date, challenge_id),
              foreign key (challenge_id)
                references public.challenge_catalog(id)
            )
          $ddl$;
        when 'garden_state' then
          execute $ddl$
            create table public.garden_state (
              user_id uuid primary key references auth.users(id) on delete cascade,
              active_flower_id text references public.flower_catalog(id),
              growth_points smallint not null default 0
                check (growth_points between 0 and 6),
              lifetime_growth_points bigint not null default 0
                check (lifetime_growth_points >= 0),
              updated_at timestamptz not null default now()
            )
          $ddl$;
        when 'flower_unlocks' then
          execute $ddl$
            create table public.flower_unlocks (
              user_id uuid not null references auth.users(id) on delete cascade,
              flower_id text not null references public.flower_catalog(id),
              unlocked_at timestamptz not null default now(),
              primary key (user_id, flower_id)
            )
          $ddl$;
        when 'memories' then
          execute $ddl$
            create table public.memories (
              id uuid primary key default gen_random_uuid(),
              user_id uuid not null references auth.users(id) on delete cascade,
              type text not null check (type in ('note', 'photo', 'voice')),
              title text not null check (length(trim(title)) between 1 and 100),
              description text not null default '',
              created_at timestamptz not null default now(),
              storage_path text unique,
              duration_seconds integer,
              check (
                (type = 'note' and storage_path is null and duration_seconds is null)
                or
                (type = 'photo' and storage_path is not null and duration_seconds is null)
                or
                (type = 'voice' and storage_path is not null
                  and duration_seconds is not null and duration_seconds >= 0)
              )
            )
          $ddl$;
        when 'mood_entries' then
          execute $ddl$
            create table public.mood_entries (
              id uuid primary key default gen_random_uuid(),
              user_id uuid not null references auth.users(id) on delete cascade,
              mood text not null,
              emoji text not null,
              note text not null default '',
              created_at timestamptz not null default now()
            )
          $ddl$;
        when 'local_data_imports' then
          execute $ddl$
            create table public.local_data_imports (
              user_id uuid primary key references auth.users(id) on delete cascade,
              imported_at timestamptz not null default now(),
              source_install_id text,
              summary jsonb not null default '{}'::jsonb
            )
          $ddl$;
      end case;
    end if;
  end loop;
end;
$$;

-- Supply missing uniqueness/foreign-key constraints on previously-created
-- tables only after checking their columns above. Any conflicting legacy rows
-- make the transaction fail; no rows are removed or rewritten.
do $$
declare
  v_table text;
  v_columns text[];
  v_constraint text;
  v_key smallint[];
  v_column_list text;
  v_foreign_table text;
  v_foreign_column text;
  v_column text;
  v_local_att smallint;
begin
  for v_table, v_columns, v_constraint in
    select * from (values
      ('daily_challenges', array['local_date','challenge_position']::text[], 'daily_challenges_date_position_key'),
      ('daily_quotes', array['local_date']::text[], 'daily_quotes_pkey'),
      ('challenge_completions', array['user_id','local_date','challenge_id']::text[], 'challenge_completions_pkey'),
      ('garden_state', array['user_id']::text[], 'garden_state_pkey'),
      ('flower_unlocks', array['user_id','flower_id']::text[], 'flower_unlocks_pkey'),
      ('memories', array['id']::text[], 'memories_pkey'),
      ('mood_entries', array['id']::text[], 'mood_entries_pkey'),
      ('local_data_imports', array['user_id']::text[], 'local_data_imports_pkey')
    ) as keys(table_name, column_names, constraint_name)
  loop
    select array_agg(a.attnum::smallint order by wanted.ordinality)
      into v_key
    from unnest(v_columns) with ordinality as wanted(column_name, ordinality)
    join pg_attribute a
      on a.attrelid = format('public.%I', v_table)::regclass
     and a.attname = wanted.column_name
     and not a.attisdropped;
    if not exists (
      select 1 from pg_constraint
      where conrelid = format('public.%I', v_table)::regclass
        and contype in ('p', 'u')
        and conkey = v_key
    ) then
      select string_agg(format('%I', column_name), ', ' order by ordinality)
        into v_column_list
      from unnest(v_columns) with ordinality as wanted(column_name, ordinality);
      execute format(
        'alter table public.%I add constraint %I unique (%s)',
        v_table, v_constraint, v_column_list
      );
    end if;
  end loop;

  for v_table, v_column, v_foreign_table, v_foreign_column in
    select * from (values
      ('profiles', 'id', 'users', 'id'),
      ('daily_challenges', 'challenge_id', 'challenge_catalog', 'id'),
      ('daily_quotes', 'quote_id', 'quote_catalog', 'id'),
      ('challenge_completions', 'user_id', 'users', 'id'),
      ('challenge_completions', 'challenge_id', 'challenge_catalog', 'id'),
      ('garden_state', 'user_id', 'users', 'id'),
      ('garden_state', 'active_flower_id', 'flower_catalog', 'id'),
      ('flower_unlocks', 'user_id', 'users', 'id'),
      ('flower_unlocks', 'flower_id', 'flower_catalog', 'id'),
      ('memories', 'user_id', 'users', 'id'),
      ('mood_entries', 'user_id', 'users', 'id'),
      ('local_data_imports', 'user_id', 'users', 'id')
    ) as relationships(table_name, column_name, foreign_table, foreign_column)
  loop
    v_foreign_table := case
      when v_foreign_table = 'users' then 'auth.users'
      else 'public.' || v_foreign_table
    end;
    select attnum::smallint into v_local_att
    from pg_attribute
    where attrelid = format('public.%I', v_table)::regclass
      and attname = v_column and not attisdropped;
    if not exists (
      select 1 from pg_constraint
      where conrelid = format('public.%I', v_table)::regclass
        and contype = 'f'
        and confrelid = to_regclass(v_foreign_table)
        and conkey = array[v_local_att]::smallint[]
    ) then
      execute format(
        'alter table public.%I add constraint %I foreign key (%I) references %s (%I)',
        v_table,
        left(v_table || '_' || v_column || '_fkey', 63),
        v_column,
        v_foreign_table,
        v_foreign_column
      );
    end if;
    v_foreign_table := null;
  end loop;
end;
$$;

create index if not exists memories_user_created_at_idx
  on public.memories(user_id, created_at desc);
create index if not exists mood_entries_user_created_at_idx
  on public.mood_entries(user_id, created_at desc);

-- Do not overwrite existing accounts or progress during backfill.
do $$
declare
  v_first_flower text;
begin
  select id into v_first_flower
  from public.flower_catalog
  order by sort_order
  limit 1;
  if v_first_flower is null then
    raise exception 'flower_catalog is empty; seed it before migration';
  end if;
  if (select count(*) from public.challenge_catalog where active) < 10 then
    raise exception 'challenge_catalog must contain at least ten active rows';
  end if;
  if not exists (select 1 from public.quote_catalog where active) then
    raise exception 'quote_catalog must contain an active quote';
  end if;
  if exists (
    select 1 from (values
      ('flower-01'), ('flower-02'), ('flower-03'), ('flower-04'),
      ('flower-05'), ('flower-06'), ('flower-07'), ('flower-08'),
      ('flower-09'), ('flower-10'), ('flower-11'), ('flower-12'),
      ('flower-13'), ('flower-14'), ('flower-15'), ('flower-16'),
      ('flower-17'), ('flower-18'), ('flower-19'), ('flower-20')
    ) as expected(id)
    where not exists (
      select 1 from public.flower_catalog fc where fc.id = expected.id
    )
  ) then
    raise exception 'flower_catalog is missing one or more IDs used by this app';
  end if;

  insert into public.profiles (id, display_name)
  select u.id,
         coalesce(nullif(trim(u.raw_user_meta_data ->> 'display_name'), ''),
                  'Sunshine')
  from auth.users u
  on conflict (id) do nothing;

  insert into public.flower_unlocks (user_id, flower_id)
  select u.id, v_first_flower
  from auth.users u
  where not exists (
    select 1 from public.flower_unlocks fu where fu.user_id = u.id
  )
  on conflict (user_id, flower_id) do nothing;

  insert into public.garden_state
    (user_id, active_flower_id, growth_points, lifetime_growth_points)
  select u.id,
         (select fc.id from public.flower_catalog fc
          where not exists (
            select 1 from public.flower_unlocks fu
            where fu.user_id = u.id and fu.flower_id = fc.id
          )
          order by fc.sort_order limit 1),
         0, 0
  from auth.users u
  on conflict (user_id) do nothing;
end;
$$;

create or replace function public.petalpop_touch_profile()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from pg_timezone_names tz where tz.name = new.time_zone
  ) then
    raise exception 'Invalid IANA time zone: %', new.time_zone
      using errcode = '22023';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists petalpop_profiles_touch on public.profiles;
create trigger petalpop_profiles_touch
before update on public.profiles
for each row execute function public.petalpop_touch_profile();

create or replace function public.petalpop_on_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_first_flower text;
  v_second_flower text;
begin
  select id into v_first_flower from public.flower_catalog
    order by sort_order limit 1;
  select id into v_second_flower from public.flower_catalog
    order by sort_order offset 1 limit 1;
  if v_first_flower is null or v_second_flower is null then
    raise exception 'flower_catalog needs at least two rows';
  end if;

  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
             'Sunshine')
  )
  on conflict (id) do nothing;

  insert into public.garden_state (user_id, active_flower_id)
  values (new.id, v_second_flower)
  on conflict (user_id) do nothing;

  insert into public.flower_unlocks (user_id, flower_id)
  values (new.id, v_first_flower)
  on conflict (user_id, flower_id) do nothing;
  return new;
end;
$$;

drop trigger if exists petalpop_auth_user_created on auth.users;
create trigger petalpop_auth_user_created
after insert on auth.users
for each row execute function public.petalpop_on_auth_user_created();

create or replace function public.petalpop_ensure_daily_content()
returns date
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_time_zone text;
  v_date date;
  v_challenges text[];
  v_quotes text[];
  v_challenge_count integer;
  v_quote_count integer;
  v_offset integer;
  v_quote_offset integer;
  v_existing_assignments integer;
  i integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  select time_zone into v_time_zone
  from public.profiles where id = v_user_id;
  if v_time_zone is null then
    raise exception 'Profile not found' using errcode = 'P0002';
  end if;
  v_date := (statement_timestamp() at time zone v_time_zone)::date;

  select array_agg(id order by sort_order, id) into v_challenges
  from public.challenge_catalog where active;
  select array_agg(id order by sort_order, id) into v_quotes
  from public.quote_catalog where active;
  v_challenge_count := coalesce(array_length(v_challenges, 1), 0);
  v_quote_count := coalesce(array_length(v_quotes, 1), 0);
  if v_challenge_count < 10 or v_quote_count < 1 then
    raise exception 'Daily content catalog is not sufficiently seeded';
  end if;

  select count(*) into v_existing_assignments
  from public.daily_challenges where local_date = v_date;
  if v_existing_assignments not in (0, 10) then
    raise exception
      'Today does not have exactly zero or ten challenge assignments; review it manually rather than silently changing the daily list.';
  end if;
  if v_existing_assignments = 10 and exists (
    select 1
    from public.daily_challenges
    where local_date = v_date
      and (challenge_position < 1 or challenge_position > 10)
  ) then
    raise exception
      'Today has ten assignments but positions are outside the expected 1..10 range; review them manually.';
  end if;

  v_offset := (
    abs(hashtext('challenges:' || v_date::text)::bigint) % v_challenge_count
  )::integer;
  for i in 1..10 loop
    insert into public.daily_challenges
      (local_date, challenge_position, challenge_id)
    values (
      v_date,
      i,
      v_challenges[((v_offset + i - 1) % v_challenge_count) + 1]
    )
    on conflict do nothing;
  end loop;
  v_quote_offset := (
    abs(hashtext('quote:' || v_date::text)::bigint) % v_quote_count
  )::integer;
  insert into public.daily_quotes (local_date, quote_id)
  values (v_date, v_quotes[v_quote_offset + 1])
  on conflict (local_date) do nothing;
  return v_date;
end;
$$;

create or replace function public.get_daily_content()
returns table (
  local_date date,
  challenge_position smallint,
  challenge_id text,
  title text,
  description text,
  emoji text,
  quote text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_date date;
begin
  v_date := public.petalpop_ensure_daily_content();
  return query
  select dc.local_date, dc.challenge_position::smallint, c.id, c.title, c.description,
         c.emoji, q.quote_text
  from public.daily_challenges dc
  join public.challenge_catalog c on c.id = dc.challenge_id
  join public.daily_quotes dq on dq.local_date = dc.local_date
  join public.quote_catalog q on q.id = dq.quote_id
  where dc.local_date = v_date
  order by dc.challenge_position;
end;
$$;

create or replace function public.complete_daily_challenge(
  p_local_date date,
  p_challenge_id text
)
returns table (
  newly_completed boolean,
  growth_points smallint,
  active_flower_id text,
  unlocked_flower_id text,
  unlocked_flower_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_date date;
  v_inserted integer;
  v_active_flower text;
  v_growth smallint;
  v_next_flower text;
  v_unlocked_flower text := null;
  v_unlocked_count bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  v_date := public.petalpop_ensure_daily_content();
  if p_local_date is distinct from v_date then
    raise exception 'Challenge date is not the current local date'
      using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.daily_challenges dc
    where dc.local_date = v_date and dc.challenge_id = p_challenge_id
  ) then
    raise exception 'Challenge is not assigned for today'
      using errcode = '22023';
  end if;

  insert into public.challenge_completions (user_id, local_date, challenge_id)
  values (v_user_id, v_date, p_challenge_id)
  on conflict (user_id, local_date, challenge_id) do nothing;
  get diagnostics v_inserted = row_count;

  select gs.active_flower_id, gs.growth_points
    into v_active_flower, v_growth
  from public.garden_state gs
  where gs.user_id = v_user_id
  for update;
  if not found then
    raise exception 'Garden state not found' using errcode = 'P0002';
  end if;

  if v_inserted = 1 and v_active_flower is not null then
    v_growth := v_growth + 1;
    if v_growth >= 7 then
      v_unlocked_flower := v_active_flower;
      insert into public.flower_unlocks (user_id, flower_id)
      values (v_user_id, v_active_flower)
      on conflict (user_id, flower_id) do nothing;

      select fc.id into v_next_flower
      from public.flower_catalog fc
      where not exists (
        select 1 from public.flower_unlocks fu
        where fu.user_id = v_user_id and fu.flower_id = fc.id
      )
      order by fc.sort_order
      limit 1;
      update public.garden_state gs
      set active_flower_id = v_next_flower,
          growth_points = 0,
          lifetime_growth_points = gs.lifetime_growth_points + 1,
          updated_at = now()
      where gs.user_id = v_user_id;
      v_active_flower := v_next_flower;
      v_growth := 0;
    else
      update public.garden_state gs
      set growth_points = v_growth,
          lifetime_growth_points = gs.lifetime_growth_points + 1,
          updated_at = now()
      where gs.user_id = v_user_id;
    end if;
  end if;

  select count(*) into v_unlocked_count
  from public.flower_unlocks fu where fu.user_id = v_user_id;
  return query select (v_inserted = 1), v_growth, v_active_flower,
                      v_unlocked_flower, v_unlocked_count;
end;
$$;

-- Storage bucket must remain private. Existing bucket configuration is not
-- changed by this migration.
insert into storage.buckets
  (id, name, public, file_size_limit, allowed_mime_types)
values (
  'petalpop-private',
  'petalpop-private',
  false,
  26214400,
  array['image/jpeg','image/png','image/webp','audio/mp4','audio/aac','audio/x-m4a']
)
on conflict (id) do nothing;

-- Check bucket visibility before adding its policies.
do $$
begin
  if (select public from storage.buckets where id = 'petalpop-private') is distinct from false then
    raise exception 'petalpop-private bucket exists but is public; review it manually before proceeding';
  end if;
end;
$$;

alter table public.profiles enable row level security;
alter table public.daily_quotes enable row level security;
alter table public.challenge_completions enable row level security;
alter table public.garden_state enable row level security;
alter table public.flower_unlocks enable row level security;
alter table public.memories enable row level security;
alter table public.mood_entries enable row level security;
alter table public.local_data_imports enable row level security;
alter table public.challenge_catalog enable row level security;
alter table public.quote_catalog enable row level security;
alter table public.daily_challenges enable row level security;
alter table public.flower_catalog enable row level security;

revoke all on public.profiles, public.daily_quotes, public.challenge_completions,
  public.garden_state, public.flower_unlocks, public.memories,
  public.mood_entries, public.local_data_imports
from public, anon, authenticated;
revoke all on public.challenge_catalog, public.quote_catalog,
  public.daily_challenges, public.flower_catalog
from public, anon, authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, avatar_id, theme, time_zone)
  on public.profiles to authenticated;
grant select on public.daily_quotes, public.challenge_completions,
  public.garden_state, public.flower_unlocks to authenticated;
grant select, delete on public.memories to authenticated;
grant insert (id, user_id, type, title, description, created_at,
  storage_path, duration_seconds) on public.memories to authenticated;
grant update (title, description) on public.memories to authenticated;
grant select, insert, update, delete on public.mood_entries to authenticated;
grant select on public.local_data_imports to authenticated;
grant select on public.challenge_catalog, public.quote_catalog,
  public.daily_challenges, public.flower_catalog to authenticated;

-- A permissive PostgreSQL policy is ORed with other permissive policies.
-- Stop rather than leave an older broad policy able to bypass these owner
-- rules. Review and deliberately reconcile any reported policy first.
do $$
begin
  if exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'profiles', 'challenge_completions', 'garden_state',
        'flower_unlocks', 'memories', 'mood_entries', 'local_data_imports'
      )
      and permissive = 'PERMISSIVE'
      and policyname not in (
        'petalpop_profile_select', 'petalpop_profile_update',
        'petalpop_completions_select', 'petalpop_garden_select',
        'petalpop_unlocks_select', 'petalpop_memories_select',
        'petalpop_memories_insert', 'petalpop_memories_update',
        'petalpop_memories_delete', 'petalpop_moods_select',
        'petalpop_moods_insert', 'petalpop_moods_update',
        'petalpop_moods_delete', 'petalpop_import_receipt_select'
      )
  ) then
    raise exception
      'Existing permissive RLS policies on private tables need manual review before migration; inspect pg_policies.';
  end if;
  if exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname not in (
        'petalpop_private_read', 'petalpop_private_insert',
        'petalpop_private_update', 'petalpop_private_delete'
      )
      and ('authenticated' = any(roles) or 'public' = any(roles))
      and coalesce(qual, '') !~* 'bucket_id'
      and coalesce(with_check, '') !~* 'bucket_id'
      and coalesce(qual, '') !~* 'auth\\.uid'
      and coalesce(with_check, '') !~* 'auth\\.uid'
  ) then
    raise exception
      'A broad Storage policy needs manual review before migration; inspect storage.objects policies.';
  end if;
end;
$$;

drop policy if exists petalpop_profile_select on public.profiles;
create policy petalpop_profile_select on public.profiles
for select to authenticated using (id = (select auth.uid()));
drop policy if exists petalpop_profile_update on public.profiles;
create policy petalpop_profile_update on public.profiles
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

drop policy if exists petalpop_daily_quotes_select on public.daily_quotes;
create policy petalpop_daily_quotes_select on public.daily_quotes
for select to authenticated using (true);
drop policy if exists petalpop_catalog_select on public.challenge_catalog;
create policy petalpop_catalog_select on public.challenge_catalog
for select to authenticated using (true);
drop policy if exists petalpop_quotes_catalog_select on public.quote_catalog;
create policy petalpop_quotes_catalog_select on public.quote_catalog
for select to authenticated using (true);
drop policy if exists petalpop_daily_challenges_select on public.daily_challenges;
create policy petalpop_daily_challenges_select on public.daily_challenges
for select to authenticated using (true);
drop policy if exists petalpop_flower_catalog_select on public.flower_catalog;
create policy petalpop_flower_catalog_select on public.flower_catalog
for select to authenticated using (true);

drop policy if exists petalpop_completions_select on public.challenge_completions;
create policy petalpop_completions_select on public.challenge_completions
for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists petalpop_garden_select on public.garden_state;
create policy petalpop_garden_select on public.garden_state
for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists petalpop_unlocks_select on public.flower_unlocks;
create policy petalpop_unlocks_select on public.flower_unlocks
for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists petalpop_memories_select on public.memories;
create policy petalpop_memories_select on public.memories
for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists petalpop_memories_insert on public.memories;
create policy petalpop_memories_insert on public.memories
for insert to authenticated with check (
  user_id = (select auth.uid())
  and (storage_path is null
    or (storage.foldername(storage_path))[1] = (select auth.uid())::text)
);
drop policy if exists petalpop_memories_update on public.memories;
create policy petalpop_memories_update on public.memories
for update to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid())
  and (storage_path is null
    or (storage.foldername(storage_path))[1] = (select auth.uid())::text)
);
drop policy if exists petalpop_memories_delete on public.memories;
create policy petalpop_memories_delete on public.memories
for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists petalpop_moods_select on public.mood_entries;
create policy petalpop_moods_select on public.mood_entries
for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists petalpop_moods_insert on public.mood_entries;
create policy petalpop_moods_insert on public.mood_entries
for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists petalpop_moods_update on public.mood_entries;
create policy petalpop_moods_update on public.mood_entries
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
drop policy if exists petalpop_moods_delete on public.mood_entries;
create policy petalpop_moods_delete on public.mood_entries
for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists petalpop_import_receipt_select on public.local_data_imports;
create policy petalpop_import_receipt_select on public.local_data_imports
for select to authenticated using (user_id = (select auth.uid()));

-- Storage policy expressions constrain the UUID directory prefix.
drop policy if exists petalpop_private_read on storage.objects;
create policy petalpop_private_read on storage.objects
for select to authenticated using (
  bucket_id = 'petalpop-private'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
drop policy if exists petalpop_private_insert on storage.objects;
create policy petalpop_private_insert on storage.objects
for insert to authenticated with check (
  bucket_id = 'petalpop-private'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
drop policy if exists petalpop_private_update on storage.objects;
create policy petalpop_private_update on storage.objects
for update to authenticated using (
  bucket_id = 'petalpop-private'
  and (storage.foldername(name))[1] = (select auth.uid())::text
) with check (
  bucket_id = 'petalpop-private'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
drop policy if exists petalpop_private_delete on storage.objects;
create policy petalpop_private_delete on storage.objects
for delete to authenticated using (
  bucket_id = 'petalpop-private'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

revoke all on function public.petalpop_on_auth_user_created()
  from public, anon, authenticated;
revoke all on function public.petalpop_touch_profile()
  from public, anon, authenticated;
revoke all on function public.petalpop_ensure_daily_content()
  from public, anon;
revoke all on function public.get_daily_content() from public, anon;
revoke all on function public.complete_daily_challenge(date, text)
  from public, anon;
grant execute on function public.petalpop_ensure_daily_content()
  to authenticated;
grant execute on function public.get_daily_content() to authenticated;
grant execute on function public.complete_daily_challenge(date, text)
  to authenticated;

commit;

-- Post-migration verification (run separately in Supabase SQL Editor):
-- select table_name from information_schema.tables
-- where table_schema = 'public' order by table_name;
-- select table_name, column_name, data_type
-- from information_schema.columns where table_schema = 'public'
-- order by table_name, ordinal_position;
-- select conrelid::regclass as table_name, conname, contype
-- from pg_constraint where connamespace = 'public'::regnamespace
-- order by 1, 2;
-- select schemaname, tablename, rowsecurity
-- from pg_tables where schemaname = 'public' order by tablename;
-- select schemaname, tablename, policyname, roles, cmd, qual, with_check
-- from pg_policies where schemaname = 'public' order by tablename, policyname;
-- select tgrelid::regclass as table_name, tgname
-- from pg_trigger where not tgisinternal and tgrelid in
--   ('auth.users'::regclass, 'public.profiles'::regclass);
-- select n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname like 'petalpop_%'
--    or (n.nspname = 'public' and p.proname in
--        ('get_daily_content', 'complete_daily_challenge'));
