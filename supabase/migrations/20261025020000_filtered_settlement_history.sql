begin;
create function public.get_filtered_settlement_page(
  p_group_id uuid, p_limit integer default 50,
  p_before_settled_at timestamptz default null,
  p_before_created_at timestamptz default null, p_before_id uuid default null,
  p_include_voided boolean default true,
  p_from timestamptz default null,p_until timestamptz default null,
  p_paying_member_id uuid default null,p_receiving_member_id uuid default null,
  p_min_minor bigint default null,p_max_minor bigint default null,
  p_state text default 'all',p_oldest_first boolean default false
) returns setof jsonb language plpgsql stable security definer set search_path = pg_catalog
as $$
begin
  if auth.uid() is null or not app_private.is_active_group_member(p_group_id,auth.uid())
     or not exists (select 1 from public.profiles where id=auth.uid() and onboarding_completed_at is not null) then
    raise exception 'Group is unavailable';
  end if;
  if p_limit is null or p_limit<1 or p_limit>100
     or num_nonnulls(p_before_settled_at,p_before_created_at,p_before_id) not in (0,3)
     or p_state is null or p_state not in ('all','active','voided')
     or p_oldest_first is null
     or (p_from is not null and p_until is not null and p_until<=p_from)
     or p_min_minor<0 or p_max_minor<0 or p_max_minor<p_min_minor then
    raise exception 'Invalid history request';
  end if;
  return query
  select jsonb_build_object('settlement_id',s.id,'paying_member_id',s.paying_member_id,
    'paying_member_name',payer.display_name,'receiving_member_id',s.receiving_member_id,
    'receiving_member_name',receiver.display_name,'amount_minor',s.amount_minor,
    'settled_at',s.settled_at,'is_voided',s.voided_at is not null,'voided_at',s.voided_at,
    'created_at',s.created_at)
  from public.settlements s
  join public.group_members payer on payer.id=s.paying_member_id
  join public.group_members receiver on receiver.id=s.receiving_member_id
  where s.group_id=p_group_id and (p_include_voided or s.voided_at is null)
    and (p_from is null or s.settled_at>=p_from) and (p_until is null or s.settled_at<p_until)
    and (p_paying_member_id is null or s.paying_member_id=p_paying_member_id)
    and (p_receiving_member_id is null or s.receiving_member_id=p_receiving_member_id)
    and (p_min_minor is null or s.amount_minor>=p_min_minor) and (p_max_minor is null or s.amount_minor<=p_max_minor)
    and (p_state='all' or (p_state='active' and s.voided_at is null) or (p_state='voided' and s.voided_at is not null))
    and (p_before_id is null or (s.settled_at,s.created_at,s.id)
         < (p_before_settled_at,p_before_created_at,p_before_id) and not p_oldest_first
         or p_oldest_first and (s.settled_at,s.created_at,s.id) > (p_before_settled_at,p_before_created_at,p_before_id))
  order by case when p_oldest_first then s.settled_at end asc,case when p_oldest_first then s.created_at end asc,case when p_oldest_first then s.id end asc,
           case when not p_oldest_first then s.settled_at end desc,case when not p_oldest_first then s.created_at end desc,case when not p_oldest_first then s.id end desc limit p_limit+1;
end;
$$;


revoke all on function public.get_filtered_settlement_page(uuid,integer,timestamptz,timestamptz,uuid,boolean,timestamptz,timestamptz,uuid,uuid,bigint,bigint,text,boolean) from public,anon;
grant execute on function public.get_filtered_settlement_page(uuid,integer,timestamptz,timestamptz,uuid,boolean,timestamptz,timestamptz,uuid,uuid,bigint,bigint,text,boolean) to authenticated;
commit;
