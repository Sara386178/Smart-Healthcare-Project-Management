-- Harden the default PostgreSQL EXECUTE grants on HealthPM routines.
create or replace function public.healthpm_member()
returns boolean language sql stable security definer set search_path=public
as $$ select coalesce(public.healthpm_role() in ('admin','editor','viewer'),false) $$;

create or replace function public.healthpm_editor()
returns boolean language sql stable security definer set search_path=public
as $$ select coalesce(public.healthpm_role() in ('admin','editor'),false) $$;

revoke execute on function public.healthpm_role() from public, anon;
revoke execute on function public.healthpm_member() from public, anon;
revoke execute on function public.healthpm_editor() from public, anon;
revoke execute on function public.healthpm_first_user(uuid) from public, anon, authenticated;
revoke execute on function public.healthpm_user_created() from public, anon, authenticated;
revoke execute on function public.healthpm_validate_dependency() from public, anon, authenticated;

revoke execute on function public.healthpm_add_change(text,text,numeric,integer) from public, anon;
revoke execute on function public.healthpm_set_requirement_status(bigint,text) from public, anon;
revoke execute on function public.healthpm_decide_change(bigint,boolean) from public, anon;
revoke execute on function public.healthpm_record_closure(text,text) from public, anon;

revoke all privileges on table public.project,public.requirements,public.changes,
  public.activities,public.defects,public.risks,public.checklist,
  public.closure_records,public.project_members from public, anon;
revoke all privileges on all sequences in schema public from public, anon;
grant select,insert,update,delete on table public.project,public.requirements,
  public.changes,public.activities,public.defects,public.risks,public.checklist,
  public.closure_records,public.project_members to authenticated;
grant usage,select on all sequences in schema public to authenticated;

-- Keep future HealthPM objects created by the migration role private by default.
alter default privileges for role postgres in schema public
  revoke all privileges on tables from anon;
alter default privileges for role postgres in schema public
  revoke all privileges on sequences from anon;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon;
alter default privileges for role postgres
  revoke execute on functions from public;

grant execute on function public.healthpm_role() to authenticated;
grant execute on function public.healthpm_member() to authenticated;
grant execute on function public.healthpm_editor() to authenticated;
grant execute on function public.healthpm_add_change(text,text,numeric,integer) to authenticated;
grant execute on function public.healthpm_set_requirement_status(bigint,text) to authenticated;
grant execute on function public.healthpm_decide_change(bigint,boolean) to authenticated;
grant execute on function public.healthpm_record_closure(text,text) to authenticated;
