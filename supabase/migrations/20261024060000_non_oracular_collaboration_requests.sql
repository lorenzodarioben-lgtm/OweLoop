begin;
-- A generic response is insufficient if the sender's pending list reveals
-- whether an arbitrary email has an account. Retain an unbound request for
-- unknown recipients; only a known recipient UUID can read or accept it.
alter table public.group_invitations alter column recipient_user_id drop not null;
alter table public.guest_claim_requests alter column recipient_user_id drop not null;
create unique index group_invitations_one_open_email on public.group_invitations(group_id,recipient_email)
where accepted_at is null and revoked_at is null and declined_at is null and expired_at is null;
create unique index guest_claims_one_open_email on public.guest_claim_requests(group_id,recipient_email)
where accepted_at is null and revoked_at is null and declined_at is null and expired_at is null;
create or replace function public.create_group_invitation(
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
  on conflict do nothing;
end;
$$;

create or replace function public.create_guest_claim_request(
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


commit;
