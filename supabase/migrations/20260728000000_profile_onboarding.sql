begin;

alter table public.profiles
  add column onboarding_completed_at timestamptz;

drop policy if exists profiles_update_own on public.profiles;
revoke update on table public.profiles from authenticated;

create function public.complete_profile(p_display_name text)
returns public.profiles
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_display_name text := btrim(p_display_name);
  v_profile public.profiles;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to complete a profile';
  end if;

  if v_display_name is null or char_length(v_display_name) = 0 then
    raise exception 'Display name cannot be blank';
  end if;

  if char_length(v_display_name) > 80 then
    raise exception 'Display name must be 80 characters or fewer';
  end if;

  update public.profiles
  set display_name = v_display_name,
      onboarding_completed_at = now()
  where id = v_user_id
  returning * into v_profile;

  if not found then
    raise exception 'Profile not found';
  end if;

  return v_profile;
end;
$$;

revoke all on function public.complete_profile(text) from public;
grant execute on function public.complete_profile(text) to authenticated;

commit;
