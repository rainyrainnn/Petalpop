begin;

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
    select 1
    from public.daily_challenges dc
    where dc.local_date = v_date
      and dc.challenge_id = p_challenge_id
  ) then
    raise exception 'Challenge is not assigned for today'
      using errcode = '22023';
  end if;

  insert into public.challenge_completions
    (user_id, local_date, challenge_id)
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
        select 1
        from public.flower_unlocks fu
        where fu.user_id = v_user_id
          and fu.flower_id = fc.id
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
  from public.flower_unlocks fu
  where fu.user_id = v_user_id;

  return query
  select v_inserted = 1,
         v_growth,
         v_active_flower,
         v_unlocked_flower,
         v_unlocked_count;
end;
$$;

commit;
