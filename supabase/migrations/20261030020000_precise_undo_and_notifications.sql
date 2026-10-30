begin;

do $$
begin
  if to_regclass('public.app_notifications') is not null then
    raise exception
      'public.app_notifications already exists; inspect its columns, constraints, grants, and RLS policies before applying this migration';
  end if;
end;
$$;

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

  if v_lifetime_growth % 10 = 0 then
    select fc.id
    into v_crossed_unlock
    from public.flower_unlocks fu
    join public.flower_catalog fc on fc.id = fu.flower_id
    where fu.user_id = v_user_id
      and fu.unlocked_at = v_completed_at
    order by fc.sort_order, fc.id
    limit 1;

    if v_crossed_unlock is not null then
      delete from public.flower_unlocks fu
      where fu.user_id = v_user_id
        and fu.flower_id = v_crossed_unlock
        and fu.unlocked_at = v_completed_at;
    end if;
  end if;

  select fc.id
  into v_active_flower_id
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

create table public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('challenge_completed', 'flower_unlocked')),
  title text not null check (length(trim(title)) between 1 and 120),
  body text not null check (length(trim(body)) between 1 and 500),
  source_key text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  retracted_at timestamptz,
  unique (user_id, source_key)
);

create index if not exists app_notifications_user_created_idx
  on public.app_notifications (user_id, created_at desc);

alter table public.app_notifications enable row level security;
revoke all on public.app_notifications from public, anon, authenticated;
grant select on public.app_notifications to authenticated;
grant update (read_at) on public.app_notifications to authenticated;

drop policy if exists petalpop_notifications_select
  on public.app_notifications;
create policy petalpop_notifications_select on public.app_notifications
for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists petalpop_notifications_update
  on public.app_notifications;
create policy petalpop_notifications_update on public.app_notifications
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

do $$
begin
  if exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'app_notifications'
      and permissive = 'PERMISSIVE'
      and ('authenticated' = any(roles) or 'public' = any(roles))
      and policyname not in (
        'petalpop_notifications_select',
        'petalpop_notifications_update'
      )
  ) then
    raise exception
      'Unexpected permissive RLS policy on public.app_notifications; inspect pg_policies before continuing';
  end if;
end;
$$;

create or replace function public.petalpop_notify_challenge_completion()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_title text;
begin
  select cc.title into v_title
  from public.challenge_catalog cc
  where cc.id = new.challenge_id;

  insert into public.app_notifications (
    user_id, kind, title, body, source_key
  )
  values (
    new.user_id,
    'challenge_completed',
    'Challenge completed',
    coalesce(v_title, 'A daily challenge') || ' is complete. A lovely step '
      || 'for your garden!',
    'challenge:' || new.local_date::text || ':' || new.challenge_id || ':'
      || to_char(
        new.completed_at at time zone 'UTC',
        'YYYYMMDDHH24MISS.US'
      )
  )
  on conflict (user_id, source_key) do nothing;
  return new;
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
  v_sort_order integer;
begin
  select fc.display_name, fc.sort_order
  into v_name, v_sort_order
  from public.flower_catalog fc
  where fc.id = new.flower_id;

  if v_sort_order is null or v_sort_order <= 1 then
    return new;
  end if;

  insert into public.app_notifications (
    user_id, kind, title, body, source_key
  )
  values (
    new.user_id,
    'flower_unlocked',
    'A new flower joined your garden!',
    coalesce(v_name, 'A new flower') || ' has bloomed in your garden.',
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

create or replace function public.petalpop_retract_challenge_notification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.app_notifications an
  set retracted_at = coalesce(an.retracted_at, now())
  where an.user_id = old.user_id
    and an.source_key =
      'challenge:' || old.local_date::text || ':' || old.challenge_id || ':'
      || to_char(
        old.completed_at at time zone 'UTC',
        'YYYYMMDDHH24MISS.US'
      );
  return old;
end;
$$;

create or replace function public.petalpop_retract_flower_notification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.app_notifications an
  set retracted_at = coalesce(an.retracted_at, now())
  where an.user_id = old.user_id
    and an.source_key =
      'flower:' || old.flower_id || ':'
      || to_char(
        old.unlocked_at at time zone 'UTC',
        'YYYYMMDDHH24MISS.US'
      );
  return old;
end;
$$;

revoke all on function public.petalpop_notify_challenge_completion()
  from public, anon, authenticated;
revoke all on function public.petalpop_notify_flower_unlock()
  from public, anon, authenticated;
revoke all on function public.petalpop_retract_challenge_notification()
  from public, anon, authenticated;
revoke all on function public.petalpop_retract_flower_notification()
  from public, anon, authenticated;

drop trigger if exists petalpop_challenge_completion_notification
  on public.challenge_completions;
create trigger petalpop_challenge_completion_notification
after insert on public.challenge_completions
for each row execute function public.petalpop_notify_challenge_completion();

drop trigger if exists petalpop_flower_unlock_notification
  on public.flower_unlocks;
create trigger petalpop_flower_unlock_notification
after insert on public.flower_unlocks
for each row execute function public.petalpop_notify_flower_unlock();

drop trigger if exists petalpop_challenge_completion_retraction
  on public.challenge_completions;
create trigger petalpop_challenge_completion_retraction
after delete on public.challenge_completions
for each row execute function public.petalpop_retract_challenge_notification();

drop trigger if exists petalpop_flower_unlock_retraction
  on public.flower_unlocks;
create trigger petalpop_flower_unlock_retraction
after delete on public.flower_unlocks
for each row execute function public.petalpop_retract_flower_notification();

commit;
