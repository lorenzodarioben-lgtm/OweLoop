begin;
-- Scalar JSON snapshots cannot be silently truncated by PostgREST's row limit.
-- Canonical balance validation and authorization remain in the original RPC.
create function public.get_group_balance_snapshot(p_group_id uuid)
returns jsonb language sql stable security definer set search_path=pg_catalog
as $$ select coalesce(jsonb_agg(to_jsonb(b) order by b.is_current_user desc,b.is_removed,b.display_name,b.group_member_id),'[]'::jsonb)
from public.get_group_balances(p_group_id) b $$;
create function public.get_expense_activity_snapshot(p_expense_id uuid)
returns jsonb language sql stable security definer set search_path=pg_catalog
as $$ select coalesce(jsonb_agg(to_jsonb(a) order by a.occurred_at,a.event_id),'[]'::jsonb)
from public.get_expense_activity(p_expense_id) a $$;
create function public.get_current_groups_snapshot()
returns jsonb language plpgsql stable security definer set search_path=pg_catalog
as $$
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(g)||jsonb_build_object('group_members',jsonb_build_array(to_jsonb(m)))
    order by (g.archived_at is not null),g.created_at desc,g.id),'[]'::jsonb)
    from public.groups g join public.group_members m on m.group_id=g.id
    where m.user_id=auth.uid() and m.removed_at is null);
end;
$$;
create function public.get_group_member_snapshot(p_group_id uuid)
returns jsonb language plpgsql stable security definer set search_path=pg_catalog
as $$
begin
  if auth.uid() is null or not app_private.is_active_group_member(p_group_id,auth.uid()) then
    raise exception 'Group is unavailable';
  end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'display_name',m.display_name,
    'role',m.role,'user_id',m.user_id,'removed_at',m.removed_at) order by m.created_at,m.id),'[]'::jsonb)
    from public.group_members m where m.group_id=p_group_id and m.removed_at is null);
end;
$$;
revoke all on function public.get_group_balance_snapshot(uuid) from public;
revoke all on function public.get_expense_activity_snapshot(uuid) from public;
revoke all on function public.get_current_groups_snapshot() from public;
revoke all on function public.get_group_member_snapshot(uuid) from public;
grant execute on function public.get_group_balance_snapshot(uuid) to authenticated;
grant execute on function public.get_expense_activity_snapshot(uuid) to authenticated;
grant execute on function public.get_current_groups_snapshot() to authenticated;
grant execute on function public.get_group_member_snapshot(uuid) to authenticated;
commit;
