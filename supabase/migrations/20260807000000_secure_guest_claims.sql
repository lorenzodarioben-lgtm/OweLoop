begin;

create table public.guest_claim_requests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete restrict,
  guest_member_id uuid not null,
  recipient_user_id uuid not null references auth.users (id) on delete cascade,
  recipient_email text not null check (
    char_length(recipient_email) between 3 and 320
    and recipient_email = lower(btrim(recipient_email))
  ),
  initiated_by_member_id uuid not null references public.group_members (id) on delete restrict,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '14 days'),
  accepted_at timestamptz,
  revoked_at timestamptz,
  declined_at timestamptz,
  expired_at timestamptz,
  foreign key (guest_member_id, group_id)
    references public.group_members (id, group_id) on delete restrict,
  check (expires_at > created_at),
  check (num_nonnulls(accepted_at, revoked_at, declined_at, expired_at) <= 1)
);

create unique index guest_claim_requests_one_open_guest
  on public.guest_claim_requests (guest_member_id)
  where accepted_at is null
    and revoked_at is null
    and declined_at is null
    and expired_at is null;

create unique index guest_claim_requests_one_open_recipient_per_group
  on public.guest_claim_requests (group_id, recipient_user_id)
  where accepted_at is null
    and revoked_at is null
    and declined_at is null
    and expired_at is null;

create index guest_claim_requests_pending_recipient_lookup
  on public.guest_claim_requests (recipient_user_id, expires_at)
  where accepted_at is null
    and revoked_at is null
    and declined_at is null
    and expired_at is null;

create index guest_claim_requests_pending_group_lookup
  on public.guest_claim_requests (group_id, expires_at)
  where accepted_at is null
    and revoked_at is null
    and declined_at is null
    and expired_at is null;

alter table public.guest_claim_requests enable row level security;
revoke all on table public.guest_claim_requests from anon, authenticated;

create function app_private.expire_open_guest_claim_requests(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  update public.guest_claim_requests as claim_request
  set expired_at = now()
  where claim_request.group_id = p_group_id
    and claim_request.accepted_at is null
    and claim_request.revoked_at is null
    and claim_request.declined_at is null
    and claim_request.expired_at is null
    and claim_request.expires_at <= now();
end;
$$;

create function public.create_guest_claim_request(
  p_group_id uuid,
  p_guest_member_id uuid,
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
  v_initiator_member_id uuid;
  v_archived_at timestamptz;
  v_guest public.group_members;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to create a guest claim request';
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
  into v_initiator_member_id
  from public.group_members as member
  where member.group_id = p_group_id
    and member.user_id = v_user_id
    and member.removed_at is null
    and member.role in ('owner'::public.group_member_role, 'admin'::public.group_member_role);
  if not found then
    raise exception 'Only an active group owner or administrator can create guest claim requests';
  end if;

  select member.*
  into v_guest
  from public.group_members as member
  where member.id = p_guest_member_id
    and member.group_id = p_group_id
    and member.removed_at is null
  for update;
  if not found or v_guest.user_id is not null then
    raise exception 'This guest is unavailable for account claiming';
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

  -- Claim initiation has generic feedback and exposes no public user lookup.
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

  perform app_private.expire_open_guest_claim_requests(p_group_id);

  insert into public.guest_claim_requests (
    group_id,
    guest_member_id,
    recipient_user_id,
    recipient_email,
    initiated_by_member_id
  ) values (
    p_group_id,
    p_guest_member_id,
    v_recipient_user_id,
    v_recipient_email,
    v_initiator_member_id
  )
  on conflict do nothing;
end;
$$;

create function public.get_pending_guest_claim_requests()
returns table (
  claim_request_id uuid,
  group_id uuid,
  group_name text,
  currency_code text,
  guest_member_id uuid,
  guest_display_name text,
  initiated_by_display_name text,
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
    raise exception 'Authentication is required to view guest claim requests';
  end if;

  return query
  select
    claim_request.id,
    group_record.id,
    group_record.name,
    group_record.currency_code,
    guest.id,
    guest.display_name,
    initiator.display_name,
    claim_request.expires_at
  from public.guest_claim_requests as claim_request
  join public.groups as group_record on group_record.id = claim_request.group_id
  join public.group_members as guest on guest.id = claim_request.guest_member_id
  join public.group_members as initiator on initiator.id = claim_request.initiated_by_member_id
  where claim_request.recipient_user_id = v_user_id
    and claim_request.accepted_at is null
    and claim_request.revoked_at is null
    and claim_request.declined_at is null
    and claim_request.expired_at is null
    and claim_request.expires_at > now()
    and group_record.archived_at is null
    and guest.removed_at is null
    and guest.user_id is null
  order by claim_request.created_at desc;
end;
$$;

create function public.get_group_guest_claim_requests(p_group_id uuid)
returns table (
  claim_request_id uuid,
  guest_member_id uuid,
  guest_display_name text,
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
    raise exception 'Only an active group owner or administrator can view guest claim requests';
  end if;

  perform app_private.expire_open_guest_claim_requests(p_group_id);

  return query
  select
    claim_request.id,
    guest.id,
    guest.display_name,
    claim_request.recipient_email,
    claim_request.created_at,
    claim_request.expires_at
  from public.guest_claim_requests as claim_request
  join public.group_members as guest on guest.id = claim_request.guest_member_id
  where claim_request.group_id = p_group_id
    and claim_request.accepted_at is null
    and claim_request.revoked_at is null
    and claim_request.declined_at is null
    and claim_request.expired_at is null
  order by claim_request.created_at desc;
end;
$$;

create function public.accept_guest_claim_request(p_claim_request_id uuid)
returns public.group_members
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_claim_request public.guest_claim_requests;
  v_archived_at timestamptz;
  v_guest public.group_members;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to accept a guest claim request';
  end if;

  select claim_request.*
  into v_claim_request
  from public.guest_claim_requests as claim_request
  where claim_request.id = p_claim_request_id
    and claim_request.recipient_user_id = v_user_id
  for update;
  if not found then
    raise exception 'Guest claim request is unavailable';
  end if;

  select group_record.archived_at
  into v_archived_at
  from public.groups as group_record
  where group_record.id = v_claim_request.group_id
  for update;
  if not found or v_archived_at is not null then
    raise exception 'Group is unavailable';
  end if;

  if v_claim_request.accepted_at is not null
    or v_claim_request.revoked_at is not null
    or v_claim_request.declined_at is not null
    or v_claim_request.expired_at is not null
    or v_claim_request.expires_at <= now() then
    raise exception 'Guest claim request is unavailable';
  end if;

  select member.*
  into v_guest
  from public.group_members as member
  where member.id = v_claim_request.guest_member_id
    and member.group_id = v_claim_request.group_id
    and member.removed_at is null
  for update;
  if not found or v_guest.user_id is not null then
    raise exception 'This guest is unavailable for account claiming';
  end if;

  if exists (
    select 1
    from public.group_members as member
    where member.group_id = v_claim_request.group_id
      and member.user_id = v_user_id
      and member.removed_at is null
  ) then
    raise exception 'You are already an active member of this group';
  end if;

  update public.group_members
  set user_id = v_user_id
  where id = v_guest.id
  returning * into v_guest;

  update public.guest_claim_requests
  set accepted_at = now()
  where id = v_claim_request.id;

  return v_guest;
end;
$$;

create function public.decline_guest_claim_request(p_claim_request_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_claim_request public.guest_claim_requests;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to decline a guest claim request';
  end if;

  select claim_request.*
  into v_claim_request
  from public.guest_claim_requests as claim_request
  where claim_request.id = p_claim_request_id
    and claim_request.recipient_user_id = v_user_id
  for update;
  if not found
    or v_claim_request.accepted_at is not null
    or v_claim_request.revoked_at is not null
    or v_claim_request.declined_at is not null
    or v_claim_request.expired_at is not null
    or v_claim_request.expires_at <= now() then
    raise exception 'Guest claim request is unavailable';
  end if;

  update public.guest_claim_requests
  set declined_at = now()
  where id = v_claim_request.id;
end;
$$;

create function public.revoke_guest_claim_request(p_claim_request_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_claim_request public.guest_claim_requests;
  v_archived_at timestamptz;
begin
  select claim_request.*
  into v_claim_request
  from public.guest_claim_requests as claim_request
  where claim_request.id = p_claim_request_id
  for update;
  if not found then
    raise exception 'Guest claim request is unavailable';
  end if;

  if auth.uid() is null
    or not app_private.is_group_admin(v_claim_request.group_id, auth.uid()) then
    raise exception 'Only an active group owner or administrator can revoke guest claim requests';
  end if;

  select group_record.archived_at
  into v_archived_at
  from public.groups as group_record
  where group_record.id = v_claim_request.group_id
  for update;
  if not found or v_archived_at is not null then
    raise exception 'Group is unavailable';
  end if;

  if v_claim_request.accepted_at is not null
    or v_claim_request.revoked_at is not null
    or v_claim_request.declined_at is not null
    or v_claim_request.expired_at is not null
    or v_claim_request.expires_at <= now() then
    raise exception 'Guest claim request is unavailable';
  end if;

  update public.guest_claim_requests
  set revoked_at = now()
  where id = v_claim_request.id;
end;
$$;

revoke all on function app_private.expire_open_guest_claim_requests(uuid) from public;
revoke all on function public.create_guest_claim_request(uuid, uuid, text) from public;
revoke all on function public.get_pending_guest_claim_requests() from public;
revoke all on function public.get_group_guest_claim_requests(uuid) from public;
revoke all on function public.accept_guest_claim_request(uuid) from public;
revoke all on function public.decline_guest_claim_request(uuid) from public;
revoke all on function public.revoke_guest_claim_request(uuid) from public;

grant execute on function public.create_guest_claim_request(uuid, uuid, text) to authenticated;
grant execute on function public.get_pending_guest_claim_requests() to authenticated;
grant execute on function public.get_group_guest_claim_requests(uuid) to authenticated;
grant execute on function public.accept_guest_claim_request(uuid) to authenticated;
grant execute on function public.decline_guest_claim_request(uuid) to authenticated;
grant execute on function public.revoke_guest_claim_request(uuid) to authenticated;

commit;
