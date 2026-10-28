
begin;

-- Verify the current growth constraint before changing it.
do $$
declare
  v_definition text;
begin
  select pg_get_constraintdef(oid)
    into v_definition
  from pg_constraint
  where conrelid = 'public.garden_state'::regclass
    and conname = 'garden_state_growth_points_check'
    and contype = 'c';

  if v_definition is null then
    raise exception
      'Expected garden_state_growth_points_check was not found; inspect the live schema before applying this migration';
  end if;

  if v_definition not ilike '%growth_points%'
     or (
       v_definition not ilike '%<= 6%'
       and v_definition not ilike '%between 0 and 6%'
       and v_definition not ilike '%<= 9%'
       and v_definition not ilike '%between 0 and 9%'
     ) then
    raise exception
      'Unexpected definition for garden_state_growth_points_check: %',
      v_definition;
  end if;

  alter table public.garden_state
    drop constraint garden_state_growth_points_check;
end;
$$;

-- Preserve lifetime totals and existing unlocks.
-- Active progress is determined only by lifetime_growth_points modulo 10.
with next_flowers as (
  select
    gs.user_id,
    (
      select fc.id
      from public.flower_catalog fc
      where not exists (
        select 1
        from public.flower_unlocks fu
        where fu.user_id = gs.user_id
          and fu.flower_id = fc.id
      )
      order by fc.sort_order, fc.id
      limit 1
    ) as next_flower_id
  from public.garden_state gs
)
update public.garden_state gs
set
  active_flower_id = nf.next_flower_id,
  growth_points = case
    when nf.next_flower_id is null then 0
    else mod(gs.lifetime_growth_points, 10)::smallint
  end,
  updated_at = now()
from next_flowers nf
where nf.user_id = gs.user_id;

alter table public.garden_state
  add constraint garden_state_growth_points_check
  check (growth_points between 0 and 9);

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
  v_lifetime_growth bigint;
  v_new_lifetime_growth bigint;
  v_candidate_flower text;
  v_next_flower text;
  v_active_flower text;
  v_growth smallint;
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

  -- Lock the garden row before recording a completion.
  select gs.lifetime_growth_points
  into v_lifetime_growth
  from public.garden_state gs
  where gs.user_id = v_user_id
  for update;

  if not found then
    raise exception 'Garden state not found'
      using errcode = 'P0002';
  end if;

  -- A unique completion awards at most one lifetime point.
  insert into public.challenge_completions (
    user_id,
    local_date,
    challenge_id
  )
  values (
    v_user_id,
    v_date,
    p_challenge_id
  )
  on conflict (user_id, local_date, challenge_id) do nothing;

  get diagnostics v_inserted = row_count;

  if v_inserted = 1 then
    v_new_lifetime_growth := v_lifetime_growth + 1;

    -- Always select the first flower that has not been unlocked.
    select fc.id
    into v_candidate_flower
    from public.flower_catalog fc
    where not exists (
      select 1
      from public.flower_unlocks fu
      where fu.user_id = v_user_id
        and fu.flower_id = fc.id
    )
    order by fc.sort_order, fc.id
    limit 1;

    if v_candidate_flower is null then
      -- No locked flowers remain. Lifetime points still accumulate.
      update public.garden_state gs
      set
        active_flower_id = null,
        growth_points = 0,
        lifetime_growth_points = v_new_lifetime_growth,
        updated_at = now()
      where gs.user_id = v_user_id;

    elsif mod(v_new_lifetime_growth, 10) = 0 then
      -- Unlock only at lifetime totals divisible by ten.
      insert into public.flower_unlocks (
        user_id,
        flower_id
      )
      values (
        v_user_id,
        v_candidate_flower
      )
      on conflict (user_id, flower_id) do nothing
      returning flower_id into v_unlocked_flower;

      -- Find the next still-locked flower.
      select fc.id
      into v_next_flower
      from public.flower_catalog fc
      where not exists (
        select 1
        from public.flower_unlocks fu
        where fu.user_id = v_user_id
          and fu.flower_id = fc.id
      )
      order by fc.sort_order, fc.id
      limit 1;

      update public.garden_state gs
      set
        active_flower_id = v_next_flower,
        growth_points = 0,
        lifetime_growth_points = v_new_lifetime_growth,
        updated_at = now()
      where gs.user_id = v_user_id;

    else
      -- Derive growth directly from the new lifetime total.
      v_growth :=
        mod(v_new_lifetime_growth, 10)::smallint;

      update public.garden_state gs
      set
        active_flower_id = v_candidate_flower,
        growth_points = v_growth,
        lifetime_growth_points = v_new_lifetime_growth,
        updated_at = now()
      where gs.user_id = v_user_id;
    end if;
  end if;

  -- Return the persisted garden state, including on duplicate completion.
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
