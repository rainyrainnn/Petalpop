begin;

do $$
begin
  if to_regclass('public.flower_catalog') is null
     or to_regclass('public.profiles') is null
     or to_regclass('public.garden_state') is null
     or to_regclass('public.flower_unlocks') is null
     or to_regclass('auth.users') is null then
    raise exception
      'Expected PetalPop auth and garden tables were not found; apply the existing backend migrations first';
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'auth.users'::regclass
      and tgname = 'petalpop_auth_user_created'
      and not tgisinternal
  ) then
    raise exception
      'The PetalPop auth-user trigger was not found; inspect the installed backend migration before continuing';
  end if;

  if not exists (
    select 1
    from public.flower_catalog
    where id = 'flower-01'
  ) then
    raise exception
      'flower_catalog is missing flower-01; inspect the catalog before continuing';
  end if;

  if (
    select fc.id
    from public.flower_catalog fc
    order by fc.sort_order, fc.id
    limit 1
  ) <> 'flower-01' then
    raise exception
      'flower-01 must be the first flower by sort_order; inspect the catalog before continuing';
  end if;
end;
$$;

create or replace function public.petalpop_on_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_first_flower text;
begin
  select id
  into v_first_flower
  from public.flower_catalog
  where id = 'flower-01';

  if v_first_flower is null then
    raise exception 'flower_catalog is missing flower-01';
  end if;

  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
             'Sunshine')
  )
  on conflict (id) do nothing;

  insert into public.garden_state (
    user_id,
    active_flower_id,
    growth_points,
    lifetime_growth_points
  )
  values (new.id, v_first_flower, 0, 0)
  on conflict (user_id) do nothing;

  return new;
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
  v_active_sort_order bigint;
  v_unlock_sort_order bigint;
  v_growth smallint;
  v_lifetime_growth bigint;
  v_active_is_unlocked boolean;
  v_flower_to_unlock text;
  v_next_flower text;
  v_unlocked_flower text := null;
  v_unlocked_count bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required'
      using errcode = '28000';
  end if;

  v_date := public.petalpop_ensure_daily_content();
  if p_local_date is distinct from v_date then
    raise exception 'Challenge date is not the current local date'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.daily_challenges dc
    where dc.local_date = v_date
      and dc.challenge_id = p_challenge_id
  ) then
    raise exception 'Challenge is not assigned for today'
      using errcode = '22023';
  end if;

  select
    gs.active_flower_id,
    gs.growth_points,
    gs.lifetime_growth_points
  into v_active_flower, v_growth, v_lifetime_growth
  from public.garden_state gs
  where gs.user_id = v_user_id
  for update;

  if not found then
    raise exception 'Garden state not found'
      using errcode = 'P0002';
  end if;

  insert into public.challenge_completions (
    user_id,
    local_date,
    challenge_id
  )
  values (v_user_id, v_date, p_challenge_id)
  on conflict (user_id, local_date, challenge_id) do nothing;

  get diagnostics v_inserted = row_count;

  if v_inserted = 1 then
    v_lifetime_growth := v_lifetime_growth + 1;

    if v_active_flower is null then
      select fc.id, fc.sort_order
      into v_flower_to_unlock, v_unlock_sort_order
      from public.flower_catalog fc
      order by fc.sort_order, fc.id
      offset ((v_lifetime_growth - 1) / 10)
      limit 1;

      if found then
        v_growth := (v_lifetime_growth % 10)::smallint;
        if v_growth = 0 then
          insert into public.flower_unlocks (user_id, flower_id)
          values (v_user_id, v_flower_to_unlock)
          on conflict (user_id, flower_id) do nothing
          returning flower_id into v_unlocked_flower;

          select fc.id
          into v_next_flower
          from public.flower_catalog fc
          where (fc.sort_order, fc.id) > (
            v_unlock_sort_order,
            v_flower_to_unlock
          )
          order by fc.sort_order, fc.id
          limit 1;

          v_active_flower := v_next_flower;
        else
          v_active_flower := v_flower_to_unlock;
        end if;

        update public.garden_state gs
        set
          active_flower_id = v_active_flower,
          growth_points = v_growth,
          lifetime_growth_points = v_lifetime_growth,
          updated_at = now()
        where gs.user_id = v_user_id;
      else
        update public.garden_state gs
        set
          growth_points = 0,
          lifetime_growth_points = v_lifetime_growth,
          updated_at = now()
        where gs.user_id = v_user_id;
      end if;
    else
      select fc.sort_order
      into v_active_sort_order
      from public.flower_catalog fc
      where fc.id = v_active_flower;

      if not found then
        raise exception 'Active flower is missing from flower_catalog'
          using errcode = 'P0002';
      end if;

      v_growth := v_growth + 1;
      if v_growth < 10 then
        update public.garden_state gs
        set
          growth_points = v_growth,
          lifetime_growth_points = v_lifetime_growth,
          updated_at = now()
        where gs.user_id = v_user_id;
      else
        select exists (
          select 1
          from public.flower_unlocks fu
          where fu.user_id = v_user_id
            and fu.flower_id = v_active_flower
        )
        into v_active_is_unlocked;

        if v_active_is_unlocked then
          select fc.id
          into v_flower_to_unlock
          from public.flower_catalog fc
          where (fc.sort_order, fc.id) > (
            v_active_sort_order,
            v_active_flower
          )
          order by fc.sort_order, fc.id
          limit 1;
        else
          v_flower_to_unlock := v_active_flower;
        end if;

        if v_flower_to_unlock is not null then
          select fc.sort_order
          into v_unlock_sort_order
          from public.flower_catalog fc
          where fc.id = v_flower_to_unlock;

          insert into public.flower_unlocks (user_id, flower_id)
          values (v_user_id, v_flower_to_unlock)
          on conflict (user_id, flower_id) do nothing
          returning flower_id into v_unlocked_flower;

          select fc.id
          into v_next_flower
          from public.flower_catalog fc
          where (fc.sort_order, fc.id) > (
            v_unlock_sort_order,
            v_flower_to_unlock
          )
          order by fc.sort_order, fc.id
          limit 1;

          if v_active_is_unlocked then
            v_next_flower := v_flower_to_unlock;
          end if;
        else
          v_next_flower := null;
        end if;

        update public.garden_state gs
        set
          active_flower_id = v_next_flower,
          growth_points = 0,
          lifetime_growth_points = v_lifetime_growth,
          updated_at = now()
        where gs.user_id = v_user_id;
      end if;
    end if;
  end if;

  select gs.active_flower_id, gs.growth_points
  into v_active_flower, v_growth
  from public.garden_state gs
  where gs.user_id = v_user_id;

  select count(*)
  into v_unlocked_count
  from public.flower_unlocks fu
  where fu.user_id = v_user_id;

  return query
  select
    v_inserted = 1,
    v_growth,
    v_active_flower,
    v_unlocked_flower,
    v_unlocked_count;
end;
$$;

create or replace function public.petalpop_notify_flower_unlock()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name text;
begin
  select fc.display_name
  into v_name
  from public.flower_catalog fc
  where fc.id = new.flower_id;

  if v_name is null then
    return new;
  end if;

  insert into public.app_notifications (
    user_id, kind, title, body, source_key
  )
  values (
    new.user_id,
    'flower_unlocked',
    'A new flower joined your garden!',
    v_name || ' has bloomed in your garden.',
    'flower:' || new.flower_id || ':'
      || to_char(
        new.unlocked_at at time zone 'UTC',
        'YYYYMMDDHH24MISS.US'
      )
  )
  on conflict (user_id, source_key) do nothing;
  return new;
end;
$$;

revoke all on function public.complete_daily_challenge(date, text)
  from public, anon;
grant execute on function public.complete_daily_challenge(date, text)
  to authenticated;

revoke all on function public.petalpop_notify_flower_unlock()
  from public, anon, authenticated;

commit;
