begin;

-- Calendar dates are evaluated by PostgreSQL in the schedule's IANA zone.
create function app_private.schedule_due(p_anchor date,p_cadence text,p_day date)
returns boolean language sql immutable set search_path=pg_catalog as $$
select p_day>=p_anchor and case p_cadence
 when 'daily' then true
 when 'weekly' then (p_day-p_anchor)%7=0
 when 'fortnightly' then (p_day-p_anchor)%14=0
 when 'monthly' then extract(day from p_day)=least(extract(day from p_anchor),
   extract(day from (date_trunc('month',p_day)+interval '1 month - 1 day')))
 else false end;
$$;
revoke all on function app_private.schedule_due(date,text,date) from public,anon,authenticated;

create table public.expense_schedules(
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references public.groups(id),
 template_id uuid references public.expense_templates(id) on delete set null,
 template_name text not null,
 payload jsonb not null,
 name text not null check(char_length(name) between 1 and 80),
 cadence text not null check(cadence in ('daily','weekly','fortnightly','monthly')),
 anchor_date date not null check(anchor_date between date '2000-01-01' and date '2100-12-31'),
 timezone text not null,
 enabled boolean not null default true,
 cancelled_at timestamptz,
 revision bigint not null default 1,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now()
);
create index expense_schedules_group on public.expense_schedules(group_id,id);
create unique index expense_schedules_name on public.expense_schedules(group_id,lower(name));
create table public.expense_occurrences(
 id uuid primary key default gen_random_uuid(),
 schedule_id uuid not null references public.expense_schedules(id),
 group_id uuid not null references public.groups(id),
 revision bigint not null,
 due_date date not null,
 payload jsonb not null,
 state text not null default 'pending' check(state in ('pending','skipped','completed')),
 expense_id uuid unique references public.expenses(id),
 request_fingerprint text,
 created_at timestamptz not null default now(),
 unique(schedule_id,due_date),
 check((state='completed')=(expense_id is not null))
);
create index expense_occurrences_page on public.expense_occurrences(group_id,due_date desc,id desc);
alter table public.expense_schedules enable row level security;
alter table public.expense_occurrences enable row level security;
revoke all on public.expense_schedules,public.expense_occurrences from public,anon,authenticated;
grant select on public.expense_schedules,public.expense_occurrences to authenticated;
create policy schedule_read on public.expense_schedules for select to authenticated
 using(app_private.is_active_group_member(group_id,auth.uid()));
create policy occurrence_read on public.expense_occurrences for select to authenticated
 using(app_private.is_active_group_member(group_id,auth.uid()));

create function public.create_expense_schedule(p_template_id uuid,p_name text,p_cadence text,p_anchor_date date,p_timezone text)
returns public.expense_schedules language plpgsql security definer set search_path=pg_catalog as $$
declare t public.expense_templates; g public.groups; result public.expense_schedules;
begin
 select * into t from public.expense_templates where id=p_template_id;
 select * into g from public.groups where id=t.group_id for update;
 select * into t from public.expense_templates where id=p_template_id;
 if t.id is null or not app_private.is_active_group_member(t.group_id,auth.uid())
   or not exists(select 1 from public.profiles where id=auth.uid() and onboarding_completed_at is not null)
   or g.archived_at is not null then raise exception 'Template is unavailable'; end if;
 if p_name is null or char_length(btrim(p_name)) not between 1 and 80
   or p_cadence is null or p_cadence not in ('daily','weekly','fortnightly','monthly')
   or p_anchor_date is null or p_anchor_date not between date '2000-01-01' and date '2100-12-31'
   or p_timezone is null or not exists(select 1 from pg_timezone_names where name=p_timezone)
   then raise exception 'Invalid schedule configuration'; end if;
 if (select count(*) from public.expense_schedules where group_id=t.group_id)>=100 then raise exception 'Group schedule limit reached'; end if;
 insert into public.expense_schedules(group_id,template_id,template_name,payload,name,cadence,anchor_date,timezone,created_by)
 values(t.group_id,t.id,t.name,t.payload,btrim(p_name),p_cadence,p_anchor_date,p_timezone,auth.uid()) returning * into result;
 return result;
end;
$$;

create function public.update_expense_schedule(p_schedule_id uuid,p_expected_revision bigint,
 p_name text,p_cadence text,p_anchor_date date,p_timezone text,p_enabled boolean,p_cancel boolean default false)
returns public.expense_schedules language plpgsql security definer set search_path=pg_catalog as $$
declare s public.expense_schedules; g public.groups; calendar_changed boolean;
begin
 select * into s from public.expense_schedules where id=p_schedule_id;
 select * into g from public.groups where id=s.group_id for update;
 select * into s from public.expense_schedules where id=p_schedule_id;
 if s.id is null or not app_private.is_active_group_member(s.group_id,auth.uid())
   or not(coalesce(s.created_by=auth.uid(),false) or app_private.is_group_admin(s.group_id,auth.uid()))
   or g.archived_at is not null or s.cancelled_at is not null then raise exception 'Schedule is unavailable'; end if;
 if p_expected_revision is null or s.revision<>p_expected_revision then raise exception 'Schedule changed; reload before editing'; end if;
 if p_name is null or char_length(btrim(p_name)) not between 1 and 80
   or p_cadence is null or p_cadence not in ('daily','weekly','fortnightly','monthly')
   or p_anchor_date is null or p_anchor_date not between date '2000-01-01' and date '2100-12-31'
   or p_timezone is null or not exists(select 1 from pg_timezone_names where name=p_timezone)
   or p_enabled is null or p_cancel is null then raise exception 'Invalid schedule configuration'; end if;
 calendar_changed:=(s.cadence,s.anchor_date,s.timezone) is distinct from (p_cadence,p_anchor_date,p_timezone);
 if calendar_changed and p_anchor_date<=(now() at time zone p_timezone)::date then raise exception 'Calendar edits must start tomorrow or later'; end if;
 if calendar_changed then
   -- Retain old due history; supersede only future unposted proposals.
   update public.expense_occurrences set state='skipped' where schedule_id=s.id and state='pending'
      and due_date>(now() at time zone s.timezone)::date;
 end if;
 update public.expense_schedules set name=btrim(p_name),cadence=p_cadence,anchor_date=p_anchor_date,timezone=p_timezone,
   enabled=p_enabled and not p_cancel,cancelled_at=case when p_cancel then now() else null end,
   revision=revision+1 where id=s.id returning * into s;
 return s;
end;
$$;

create function public.get_expense_schedule_page(p_group_id uuid,p_before_date date default null,p_before_id uuid default null)
returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare g public.groups; result jsonb;
begin
 select * into g from public.groups where id=p_group_id for update;
 if not app_private.is_active_group_member(p_group_id,auth.uid())
   or not exists(select 1 from public.profiles where id=auth.uid() and onboarding_completed_at is not null)
   then raise exception 'Group is unavailable'; end if;
 if num_nonnulls(p_before_date,p_before_id) not in (0,2) then raise exception 'Invalid occurrence cursor'; end if;
 if g.archived_at is null then
   insert into public.expense_occurrences(schedule_id,group_id,revision,due_date,payload)
   select s.id,s.group_id,s.revision,d.day,s.payload from public.expense_schedules s
   cross join lateral (select (now() at time zone s.timezone)::date+i as day from generate_series(-90,0) i) d
   where s.group_id=p_group_id and s.enabled and s.cancelled_at is null
     and app_private.schedule_due(s.anchor_date,s.cadence,d.day)
     -- Pauses/name edits do not regenerate calendar identities in later revisions.
     and not exists(select 1 from public.expense_occurrences o where o.schedule_id=s.id and o.due_date=d.day)
   on conflict do nothing;
 end if;
 select jsonb_build_object('schedules',(select coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object(
   'next_due_date',(select min(day) from (select greatest((now() at time zone s.timezone)::date+1,s.anchor_date)+i as day from generate_series(0,31) i) days where app_private.schedule_due(s.anchor_date,s.cadence,day)),
   'can_edit',g.archived_at is null and s.cancelled_at is null and (coalesce(s.created_by=auth.uid(),false) or app_private.is_group_admin(s.group_id,auth.uid()))) order by s.created_at,s.id),'[]')
   from public.expense_schedules s where s.group_id=p_group_id),
   'occurrences',(select coalesce(jsonb_agg(row order by due_date desc,id desc),'[]') from (
     select o.due_date,o.id,to_jsonb(o)||jsonb_build_object('name',s.name,'template_name',s.template_name,
       'can_review',o.state='pending' and s.enabled and s.cancelled_at is null and g.archived_at is null
          and o.due_date<=(now() at time zone s.timezone)::date,
       'timezone',s.timezone) as row
     from public.expense_occurrences o join public.expense_schedules s on s.id=o.schedule_id
     where o.group_id=p_group_id and (p_before_id is null or (o.due_date,o.id)<(p_before_date,p_before_id))
     order by o.due_date desc,o.id desc limit 51) page)) into result;
 return result;
end;
$$;

create function public.skip_expense_occurrence(p_occurrence_id uuid)
returns void language plpgsql security definer set search_path=pg_catalog as $$
declare o public.expense_occurrences; s public.expense_schedules; g public.groups;
begin
 select * into o from public.expense_occurrences where id=p_occurrence_id;
 select * into g from public.groups where id=o.group_id for update;
 select * into o from public.expense_occurrences where id=p_occurrence_id for update;
 select * into s from public.expense_schedules where id=o.schedule_id;
 if o.id is null or not app_private.is_active_group_member(o.group_id,auth.uid()) or g.archived_at is not null
   or not s.enabled or s.cancelled_at is not null then raise exception 'Occurrence is unavailable'; end if;
 if o.state='completed' then raise exception 'A confirmed occurrence cannot be skipped'; end if;
 update public.expense_occurrences set state='skipped' where id=o.id;
end;
$$;

create function public.post_scheduled_expense(p_occurrence_id uuid,p_group_id uuid,p_description text,
 p_total_amount_minor bigint,p_occurred_at timestamptz,p_payers jsonb,p_splits jsonb,p_operation_id uuid,p_category_key text default null)
returns public.expenses language plpgsql security definer set search_path=pg_catalog as $$
declare o public.expense_occurrences; s public.expense_schedules; g public.groups; e public.expenses; fingerprint text;
begin
 select * into g from public.groups where id=p_group_id for update;
 select * into o from public.expense_occurrences where id=p_occurrence_id and group_id=p_group_id for update;
 if o.id is null or not app_private.is_active_group_member(p_group_id,auth.uid())
   or not exists(select 1 from public.profiles where id=auth.uid() and onboarding_completed_at is not null)
   then raise exception 'Occurrence is unavailable'; end if;
 fingerprint:=jsonb_build_object('description',btrim(p_description),'amount',p_total_amount_minor,
   'at',p_occurred_at,'payers',p_payers,'splits',p_splits,'category',p_category_key)::text;
 if o.state='completed' then
   if o.request_fingerprint<>fingerprint then raise exception 'Occurrence already posted with different fields'; end if;
   select * into e from public.expenses where id=o.expense_id;
   return e;
 end if;
 select * into s from public.expense_schedules where id=o.schedule_id;
 if o.state<>'pending' or not s.enabled or s.cancelled_at is not null or g.archived_at is not null
   or o.due_date>(now() at time zone s.timezone)::date then raise exception 'Occurrence is not actionable'; end if;
 select * into e from public.create_categorized_expense(p_group_id,p_description,p_total_amount_minor,p_occurred_at,p_payers,p_splits,p_operation_id,p_category_key);
 update public.expense_occurrences set state='completed',expense_id=e.id,request_fingerprint=fingerprint where id=o.id;
 return e;
end;
$$;

revoke all on function public.create_expense_schedule(uuid,text,text,date,text) from public,anon;
revoke all on function public.update_expense_schedule(uuid,bigint,text,text,date,text,boolean,boolean) from public,anon;
revoke all on function public.get_expense_schedule_page(uuid,date,uuid) from public,anon;
revoke all on function public.skip_expense_occurrence(uuid) from public,anon;
revoke all on function public.post_scheduled_expense(uuid,uuid,text,bigint,timestamptz,jsonb,jsonb,uuid,text) from public,anon;
grant execute on function public.create_expense_schedule(uuid,text,text,date,text),
 public.update_expense_schedule(uuid,bigint,text,text,date,text,boolean,boolean),
 public.get_expense_schedule_page(uuid,date,uuid),public.skip_expense_occurrence(uuid),
 public.post_scheduled_expense(uuid,uuid,text,bigint,timestamptz,jsonb,jsonb,uuid,text) to authenticated;

alter function public.export_personal_data() rename to export_personal_data_pre_schedule_internal;
revoke all on function public.export_personal_data_pre_schedule_internal() from public,anon,authenticated;
create function public.export_personal_data() returns jsonb language sql stable security definer set search_path=pg_catalog as $$
select public.export_personal_data_pre_schedule_internal()||jsonb_build_object(
 'readable_schedules',(select coalesce(jsonb_agg(to_jsonb(s) order by s.id),'[]') from public.expense_schedules s where app_private.is_active_group_member(s.group_id,auth.uid())),
 'readable_occurrences',(select coalesce(jsonb_agg(to_jsonb(o) order by o.id),'[]') from public.expense_occurrences o where app_private.is_active_group_member(o.group_id,auth.uid())));
$$;
revoke all on function public.export_personal_data() from public,anon;
grant execute on function public.export_personal_data() to authenticated;
commit;
