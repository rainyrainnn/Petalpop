begin;

do $$
declare
  v_catalog_count bigint;
begin
  select count(*) into v_catalog_count
  from public.flower_catalog;

  if v_catalog_count <> 20 then
    raise exception
      'Expected exactly 20 existing flower_catalog rows, found %; inspect the catalog before applying this migration',
      v_catalog_count;
  end if;

  if exists (
    select 1
    from generate_series(1, 20) as expected(number)
    where not exists (
      select 1
      from public.flower_catalog fc
      where fc.id = format('flower-%s', lpad(expected.number::text, 2, '0'))
    )
  ) then
    raise exception
      'flower_catalog is missing one or more expected flower-01 through flower-20 IDs';
  end if;
end;
$$;

-- The active flower is available while it grows. Keep all existing unlock
-- rows and add any unlocks earned by lifetime growth, without changing totals.
with ordered_catalog as (
  select
    fc.id,
    row_number() over (order by fc.sort_order, fc.id) as position
  from public.flower_catalog fc
),
earned_unlocks as (
  select
    gs.user_id,
    oc.id as flower_id
  from public.garden_state gs
  cross join ordered_catalog oc
  where oc.position <= least(gs.lifetime_growth_points / 10 + 1, 20)
)
insert into public.flower_unlocks (user_id, flower_id)
select user_id, flower_id
from earned_unlocks
on conflict (user_id, flower_id) do nothing;

with ordered_catalog as (
  select
    fc.id,
    row_number() over (order by fc.sort_order, fc.id) as position
  from public.flower_catalog fc
),
state_targets as (
  select
    gs.user_id,
    gs.lifetime_growth_points,
    active.id as active_flower_id
  from public.garden_state gs
  left join ordered_catalog active
    on active.position = gs.lifetime_growth_points / 10 + 1
)
update public.garden_state gs
set
  active_flower_id = target.active_flower_id,
  growth_points = case
    when target.active_flower_id is null then 0
    else mod(target.lifetime_growth_points, 10)::smallint
  end,
  updated_at = now()
from state_targets target
where target.user_id = gs.user_id;

create or replace function public.petalpop_on_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_first_flower text;
begin
  select id into v_first_flower
  from public.flower_catalog
  order by sort_order, id
  limit 1;

  if v_first_flower is null then
    raise exception 'flower_catalog is empty';
  end if;

  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
             'Sunshine')
  )
  on conflict (id) do nothing;

  insert into public.garden_state (user_id, active_flower_id)
  values (new.id, v_first_flower)
  on conflict (user_id) do nothing;

  insert into public.flower_unlocks (user_id, flower_id)
  values (new.id, v_first_flower)
  on conflict (user_id, flower_id) do nothing;

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
  v_growth smallint;
  v_lifetime_growth bigint;
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

  -- Serialize all growth updates for one user before applying the unique
  -- completion constraint, so retries cannot award a second point.
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
      update public.garden_state gs
      set
        growth_points = 0,
        lifetime_growth_points = v_lifetime_growth,
        updated_at = now()
      where gs.user_id = v_user_id;
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
        select fc.id
        into v_next_flower
        from public.flower_catalog fc
        where (fc.sort_order, fc.id) > (
          v_active_sort_order,
          v_active_flower
        )
        order by fc.sort_order, fc.id
        limit 1;

        if v_next_flower is not null then
          insert into public.flower_unlocks (user_id, flower_id)
          values (v_user_id, v_next_flower)
          on conflict (user_id, flower_id) do nothing;
          v_unlocked_flower := v_next_flower;
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

commit;
