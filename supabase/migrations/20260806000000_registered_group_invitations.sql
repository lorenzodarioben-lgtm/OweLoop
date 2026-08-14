begin;

create table public.group_invitations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete restrict,
  recipient_user_id uuid not null references auth.users (id) on delete cascade,
  recipient_email text not null check (
    char_length(recipient_email) between 3 and 320
    and recipient_email = lower(btrim(recipient_email))
  ),
  inviter_member_id uuid not null references public.group_members (id) on delete restrict,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '14 days'),
  accepted_at timestamptz,
  revoked_at timestamptz,
  declined_at timestamptz,
  expired_at timestamptz,
  check (expires_at > created_at),
  check (num_nonnulls(accepted_at, revoked_at, declined_at, expired_at) <= 1)
);

create unique index group_invitations_one_open_recipient_per_group
  on public.group_invitations (group_id, recipient_user_id)
  where accepted_at is null
    and revoked_at is null
    and declined_at is null
    and expired_at is null;

create index group_invitations_pending_recipient_lookup
  on public.group_invitations (recipient_user_id, expires_at)
  where accepted_at is null
    and revoked_at is null
    and declined_at is null
    and expired_at is null;

create index group_invitations_pending_group_lookup
  on public.group_invitations (group_id, expires_at)
  where accepted_at is null
    and revoked_at is null
    and declined_at is null
    and expired_at is null;

alter table public.group_invitations enable row level security;
revoke all on table public.group_invitations from anon, authenticated;

create function app_private.expire_open_group_invitations(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  update public.group_invitations as invitation
  set expired_at = now()
  where invitation.group_id = p_group_id
    and invitation.accepted_at is null
    and invitation.revoked_at is null
    and invitation.declined_at is null
    and invitation.expired_at is null
    and invitation.expires_at <= now();
end;
$$;

create function public.create_group_invitation(
  p_group_id uuid,
  p_recipient_email text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_recipient_email text := lower(btrim(p_recipient_email));
  v_recipient_user_id uuid;
  v_inviter_member_id uuid;
  v_archived_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to create a group invitation';
  end if;

  select group_record.archived_at
  into v_archived_at
  from public.groups as group_record
  where group_record.id = p_group_id
  for update;
  if not found or v_archived_at is not null then
    raise exception 'Group is unavailable';
  end if;

  select member.id
  into v_inviter_member_id
  from public.group_members as member
  where member.group_id = p_group_id
    and member.user_id = v_user_id
    and member.removed_at is null
    and member.role in ('owner'::public.group_member_role, 'admin'::public.group_member_role);
  if not found then
    raise exception 'Only an active group owner or administrator can create invitations';
  end if;

  if v_recipient_email is null
    or char_length(v_recipient_email) > 320
    or v_recipient_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Enter a valid email address';
  end if;

  select user_record.id
  into v_recipient_user_id
  from auth.users as user_record
  where lower(user_record.email) = v_recipient_email
  order by user_record.created_at
  limit 1;

  -- This deliberately returns no recipient-specific result. The app shows
  -- generic feedback, so this endpoint is not a public account lookup API.
  if v_recipient_user_id is null then
    return;
  end if;

  if exists (
    select 1
    from public.group_members as member
    where member.group_id = p_group_id
      and member.user_id = v_recipient_user_id
      and member.removed_at is null
  ) then
    return;
  end if;

  perform app_private.expire_open_group_invitations(p_group_id);

  insert into public.group_invitations (
    group_id,
    recipient_user_id,
    recipient_email,
    inviter_member_id
  ) values (
    p_group_id,
    v_recipient_user_id,
    v_recipient_email,
    v_inviter_member_id
  )
  on conflict (group_id, recipient_user_id)
    where accepted_at is null
      and revoked_at is null
      and declined_at is null
      and expired_at is null
    do nothing;
end;
$$;

create function public.get_pending_group_invitations()
returns table (
  invitation_id uuid,
  group_id uuid,
  group_name text,
  currency_code text,
  inviter_display_name text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication is required to view group invitations';
  end if;

  return query
  select
    invitation.id,
    group_record.id,
    group_record.name,
    group_record.currency_code,
    inviter.display_name,
    invitation.expires_at
  from public.group_invitations as invitation
  join public.groups as group_record on group_record.id = invitation.group_id
  join public.group_members as inviter on inviter.id = invitation.inviter_member_id
  where invitation.recipient_user_id = v_user_id
    and invitation.accepted_at is null
    and invitation.revoked_at is null
    and invitation.declined_at is null
    and invitation.expired_at is null
    and invitation.expires_at > now()
    and group_record.archived_at is null
  order by invitation.created_at desc;
end;
$$;

create function public.get_group_invitations(p_group_id uuid)
returns table (
  invitation_id uuid,
  recipient_email text,
  created_at timestamptz,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if auth.uid() is null or not app_private.is_group_admin(p_group_id, auth.uid()) then
    raise exception 'Only an active group owner or administrator can view invitations';
  end if;

  perform app_private.expire_open_group_invitations(p_group_id);

  return query
  select invitation.id, invitation.recipient_email, invitation.created_at, invitation.expires_at
  from public.group_invitations as invitation
  where invitation.group_id = p_group_id
    and invitation.accepted_at is null
    and invitation.revoked_at is null
    and invitation.declined_at is null
    and invitation.expired_at is null
  order by invitation.created_at desc;
end;
$$;

create function public.accept_group_invitation(p_invitation_id uuid)
returns public.group_members
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_invitation public.group_invitations;
  v_archived_at timestamptz;
  v_display_name text;
  v_member public.group_members;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to accept a group invitation';
  end if;

  select invitation.*
  into v_invitation
  from public.group_invitations as invitation
  where invitation.id = p_invitation_id
    and invitation.recipient_user_id = v_user_id
  for update;
  if not found then
    raise exception 'Invitation is unavailable';
  end if;

  select group_record.archived_at
  into v_archived_at
  from public.groups as group_record
  where group_record.id = v_invitation.group_id
  for update;
  if not found or v_archived_at is not null then
    raise exception 'Group is unavailable';
  end if;

  if v_invitation.accepted_at is not null
    or v_invitation.revoked_at is not null
    or v_invitation.declined_at is not null
    or v_invitation.expired_at is not null
    or v_invitation.expires_at <= now() then
    raise exception 'Invitation is unavailable';
  end if;

  if exists (
    select 1
    from public.group_members as member
    where member.group_id = v_invitation.group_id
      and member.user_id = v_user_id
      and member.removed_at is null
  ) then
    raise exception 'You are already an active member of this group';
  end if;

  select profile.display_name
  into v_display_name
  from public.profiles as profile
  where profile.id = v_user_id;

  insert into public.group_members (group_id, user_id, display_name, role)
  values (
    v_invitation.group_id,
    v_user_id,
    coalesce(v_display_name, 'Member'),
    'member'::public.group_member_role
  )
  returning * into v_member;

  update public.group_invitations
  set accepted_at = now()
  where id = v_invitation.id;

  return v_member;
end;
$$;

create function public.decline_group_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_invitation public.group_invitations;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to decline a group invitation';
  end if;

  select invitation.*
  into v_invitation
  from public.group_invitations as invitation
  where invitation.id = p_invitation_id
    and invitation.recipient_user_id = v_user_id
  for update;
  if not found
    or v_invitation.accepted_at is not null
    or v_invitation.revoked_at is not null
    or v_invitation.declined_at is not null
    or v_invitation.expired_at is not null
    or v_invitation.expires_at <= now() then
    raise exception 'Invitation is unavailable';
  end if;

  update public.group_invitations
  set declined_at = now()
  where id = v_invitation.id;
end;
$$;

create function public.revoke_group_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_invitation public.group_invitations;
  v_archived_at timestamptz;
begin
  select invitation.*
  into v_invitation
  from public.group_invitations as invitation
  where invitation.id = p_invitation_id
  for update;
  if not found then
    raise exception 'Invitation is unavailable';
  end if;

  if auth.uid() is null or not app_private.is_group_admin(v_invitation.group_id, auth.uid()) then
    raise exception 'Only an active group owner or administrator can revoke invitations';
  end if;

  select group_record.archived_at
  into v_archived_at
  from public.groups as group_record
  where group_record.id = v_invitation.group_id
  for update;
  if not found or v_archived_at is not null then
    raise exception 'Group is unavailable';
  end if;

  if v_invitation.accepted_at is not null
    or v_invitation.revoked_at is not null
    or v_invitation.declined_at is not null
    or v_invitation.expired_at is not null
    or v_invitation.expires_at <= now() then
    raise exception 'Invitation is unavailable';
  end if;

  update public.group_invitations
  set revoked_at = now()
  where id = v_invitation.id;
end;
$$;

revoke all on function app_private.expire_open_group_invitations(uuid) from public;
revoke all on function public.create_group_invitation(uuid, text) from public;
revoke all on function public.get_pending_group_invitations() from public;
revoke all on function public.get_group_invitations(uuid) from public;
revoke all on function public.accept_group_invitation(uuid) from public;
revoke all on function public.decline_group_invitation(uuid) from public;
revoke all on function public.revoke_group_invitation(uuid) from public;

grant execute on function public.create_group_invitation(uuid, text) to authenticated;
grant execute on function public.get_pending_group_invitations() to authenticated;
grant execute on function public.get_group_invitations(uuid) to authenticated;
grant execute on function public.accept_group_invitation(uuid) to authenticated;
grant execute on function public.decline_group_invitation(uuid) to authenticated;
grant execute on function public.revoke_group_invitation(uuid) to authenticated;

commit;
