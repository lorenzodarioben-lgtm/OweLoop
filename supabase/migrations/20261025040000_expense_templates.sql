begin;
create table public.expense_templates(
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id),
  name text not null check(char_length(name) between 1 and 80),
  payload jsonb not null check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=20000),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default clock_timestamp()
);
create unique index expense_templates_name on public.expense_templates(group_id,lower(name));
alter table public.expense_templates enable row level security;
revoke all on public.expense_templates from public,anon,authenticated;
grant select on public.expense_templates to authenticated;
create policy template_member_read on public.expense_templates for select to authenticated
using(app_private.is_active_group_member(group_id,auth.uid()));

create function public.save_expense_template(p_group_id uuid,p_name text,p_payload jsonb,
  p_template_id uuid default null,p_expected_updated_at timestamptz default null)
returns public.expense_templates language plpgsql security definer set search_path=pg_catalog as $$
declare v_group public.groups; v_template public.expense_templates; v_key text; v_member text; v_list jsonb;
begin
  select * into v_group from public.groups where id=p_group_id for update;
  if not app_private.is_active_group_member(p_group_id,auth.uid())
     or not exists(select 1 from public.profiles where id=auth.uid() and onboarding_completed_at is not null) then raise exception 'Group is unavailable'; end if;
  if v_group.archived_at is not null then raise exception 'Archived group templates are read only'; end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 80 then raise exception 'Template name must be 1 to 80 characters'; end if;
  if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>20000 then raise exception 'Invalid template configuration'; end if;
  if exists(select 1 from jsonb_object_keys(p_payload) key where key not in('description','amount','split_method','multiple_payers','single_payer','payer_ids','participant_ids','payer_amounts','split_values','category_key')) then raise exception 'Unsupported template field'; end if;
  if jsonb_typeof(p_payload->'description') is distinct from 'string' or char_length(btrim(p_payload->>'description')) not between 1 and 500
     or coalesce(p_payload->>'split_method','equal') not in ('equal','exact','percentage','shares')
     or (p_payload?'multiple_payers' and jsonb_typeof(p_payload->'multiple_payers')<>'boolean') then raise exception 'Invalid template description or split method'; end if;
  if p_payload->>'category_key' is not null and p_payload->>'category_key' not in ('food','groceries','transport','accommodation','utilities','shopping','entertainment','travel','household','healthcare','other') then raise exception 'Invalid template category'; end if;
  if p_payload?'amount' and (jsonb_typeof(p_payload->'amount')<>'string' or char_length(p_payload->>'amount')>40) then raise exception 'Invalid template amount'; end if;
  if coalesce(p_payload->>'amount','')<>'' then
    if v_group.currency_code not in ('AUD','CAD','EUR','GBP','JPY','NZD','SGD','USD') then raise exception 'Unsupported template currency'; end if;
    if (p_payload->>'amount') !~ (case when v_group.currency_code='JPY' then '^\d+$' else '^\d+(\.\d{1,2})?$' end) then raise exception 'Invalid template amount'; end if;
    if (p_payload->>'amount')::numeric*(case when v_group.currency_code='JPY' then 1 else 100 end)>9223372036854775807 then raise exception 'Template amount exceeds supported range'; end if;
  end if;
  foreach v_key in array array['payer_ids','participant_ids'] loop
    v_list:=coalesce(p_payload->v_key,'[]');
    if jsonb_typeof(v_list)<>'array' or jsonb_array_length(v_list)>1000 then raise exception 'Invalid template participants'; end if;
    if (select count(*) from jsonb_array_elements(v_list))<>(select count(distinct value) from jsonb_array_elements(v_list)) then raise exception 'Duplicate template participants'; end if;
    for v_member in select jsonb_array_elements_text(v_list) loop
      if not exists(select 1 from public.group_members where id=v_member::uuid and group_id=p_group_id and removed_at is null) then raise exception 'Template participants must be active in this group'; end if;
    end loop;
  end loop;
  if p_payload->>'single_payer' is not null and not exists(select 1 from public.group_members where id=(p_payload->>'single_payer')::uuid and group_id=p_group_id and removed_at is null) then raise exception 'Template payer must be active in this group'; end if;
  foreach v_key in array array['payer_amounts','split_values'] loop
    v_list:=coalesce(p_payload->v_key,'{}');
    if jsonb_typeof(v_list)<>'object' then raise exception 'Invalid template allocation fields'; end if;
    for v_member in select jsonb_object_keys(v_list) loop
      if jsonb_typeof(v_list->v_member)<>'string' or char_length(v_list->>v_member)>100
         or not exists(select 1 from public.group_members where id=v_member::uuid and group_id=p_group_id and removed_at is null) then raise exception 'Invalid template allocation member'; end if;
    end loop;
  end loop;
  if p_template_id is null then
    select * into v_template from public.expense_templates where group_id=p_group_id and lower(name)=lower(btrim(p_name));
    if found then
      if v_template.created_by=auth.uid() and v_template.payload=p_payload then return v_template; end if;
      raise exception 'A template with this name already exists';
    end if;
    insert into public.expense_templates(group_id,name,payload,created_by) values(p_group_id,btrim(p_name),p_payload,auth.uid()) returning * into v_template;
  else
    select * into v_template from public.expense_templates where id=p_template_id and group_id=p_group_id;
    if not found or not(coalesce(v_template.created_by=auth.uid(),false) or app_private.is_group_admin(p_group_id,auth.uid())) then raise exception 'Template is unavailable'; end if;
    if p_expected_updated_at is null or v_template.updated_at<>p_expected_updated_at then raise exception 'Template changed; reload before editing'; end if;
    update public.expense_templates set name=btrim(p_name),payload=p_payload,updated_at=clock_timestamp() where id=p_template_id returning * into v_template;
  end if;
  return v_template;
end;
$$;

create function public.delete_expense_template(p_template_id uuid,p_expected_updated_at timestamptz)
returns void language plpgsql security definer set search_path=pg_catalog as $$
declare v_template public.expense_templates; v_group public.groups;
begin
  select * into v_template from public.expense_templates where id=p_template_id;
  select * into v_group from public.groups where id=v_template.group_id for update;
  select * into v_template from public.expense_templates where id=p_template_id;
  if v_template.id is null or not app_private.is_active_group_member(v_template.group_id,auth.uid())
    or not(coalesce(v_template.created_by=auth.uid(),false) or app_private.is_group_admin(v_template.group_id,auth.uid())) then raise exception 'Template is unavailable'; end if;
  if v_group.archived_at is not null then raise exception 'Archived group templates are read only'; end if;
  if p_expected_updated_at is null or v_template.updated_at<>p_expected_updated_at then raise exception 'Template changed; reload before deleting'; end if;
  delete from public.expense_templates where id=p_template_id;
end;
$$;
create function public.get_expense_templates(p_group_id uuid)
returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
begin
  if auth.uid() is null or not app_private.is_active_group_member(p_group_id,auth.uid()) then raise exception 'Group is unavailable'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(t)||jsonb_build_object('can_edit',coalesce(t.created_by=auth.uid(),false) or app_private.is_group_admin(p_group_id,auth.uid())) order by lower(t.name),t.id),'[]') from public.expense_templates t where t.group_id=p_group_id);
end;
$$;
revoke all on function public.get_expense_templates(uuid) from public,anon;
grant execute on function public.get_expense_templates(uuid) to authenticated;
revoke all on function public.save_expense_template(uuid,text,jsonb,uuid,timestamptz) from public,anon;
revoke all on function public.delete_expense_template(uuid,timestamptz) from public,anon;
grant execute on function public.save_expense_template(uuid,text,jsonb,uuid,timestamptz) to authenticated;
grant execute on function public.delete_expense_template(uuid,timestamptz) to authenticated;
commit;
