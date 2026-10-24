begin;
-- INSERT ... RETURNING is checked against SELECT RLS before the AFTER trigger
-- establishes membership. Return the result only after the owner exists.
create function public.create_group(p_name text,p_currency_code text)
returns public.groups language plpgsql security definer set search_path=pg_catalog
as $$
declare v_group public.groups;
begin
  if auth.uid() is null then raise exception 'Authentication is required to create a group'; end if;
  insert into public.groups(name,currency_code) values(p_name,p_currency_code)
  returning * into v_group;
  return v_group;
end;
$$;
revoke all on function public.create_group(text,text) from public;
grant execute on function public.create_group(text,text) to authenticated;
commit;
