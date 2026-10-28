begin;

create or replace function public.undo_daily_challenge(
  p_local_date date,
  p_challenge_id text
)
returns table (was_undone boolean)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_date date;
  v_completed_at timestamptz;
  v_lifetime_growth bigint;
  v_new_lifetime_growth bigint;
  v_growth smallint;
  v_active_flower_id text;
  v_crossed_unlock text;
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

  select gs.lifetime_growth_points
  into v_lifetime_growth
  from public.garden_state gs
  where gs.user_id = v_user_id
  for update;

  if not found then
    raise exception 'Garden state not found'
      using errcode = 'P0002';
  end if;

  delete from public.challenge_completions cc
  where cc.user_id = v_user_id
    and cc.local_date = v_date
    and cc.challenge_id = p_challenge_id
  returning cc.completed_at into v_completed_at;

  if not found then
    return query select false;
    return;
  end if;

  if v_lifetime_growth < 1 then
    raise exception 'Garden growth is inconsistent with challenge history'
      using errcode = '23514';
  end if;

  v_new_lifetime_growth := v_lifetime_growth - 1;
  v_growth := mod(v_new_lifetime_growth, 10)::smallint;

  select fc.id
  into v_active_flower_id
  from public.flower_catalog fc
  order by fc.sort_order, fc.id
  offset (v_new_lifetime_growth / 10)
  limit 1;

  if v_lifetime_growth % 10 = 0 then
    select fc.id
    into v_crossed_unlock
    from public.flower_catalog fc
    order by fc.sort_order, fc.id
    offset (v_lifetime_growth / 10)
    limit 1;

    if v_crossed_unlock is not null then
      delete from public.flower_unlocks fu
      where fu.user_id = v_user_id
        and fu.flower_id = v_crossed_unlock
        and fu.unlocked_at >= v_completed_at;
    end if;
  end if;

  update public.garden_state gs
  set
    active_flower_id = v_active_flower_id,
    growth_points = case when v_active_flower_id is null then 0 else v_growth end,
    lifetime_growth_points = v_new_lifetime_growth,
    updated_at = now()
  where gs.user_id = v_user_id;

  return query select true;
end;
$$;

revoke all on function public.undo_daily_challenge(date, text)
  from public, anon;
grant execute on function public.undo_daily_challenge(date, text)
  to authenticated;

commit;
