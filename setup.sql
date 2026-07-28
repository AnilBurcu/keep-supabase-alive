-- Run this once in each Supabase project (Dashboard > SQL Editor > Run).
-- Creates a one-row table and a function that the GitHub Actions workflow
-- calls once a day. The row is updated in place, so nothing ever grows.

create table if not exists public._keepalive (
  id smallint primary key check (id = 1),
  pinged_at timestamptz not null default now()
);

-- Exactly one row, forever.
insert into public._keepalive (id) values (1)
on conflict (id) do nothing;

-- RLS on with no policies: the table cannot be reached through the API directly.
alter table public._keepalive enable row level security;

-- Strip default table grants from API roles.
revoke all on table public._keepalive from anon, authenticated;

-- The only write path: overwrite the timestamp of row 1.
create or replace function public.keep_alive()
returns timestamptz
language sql
security definer
set search_path = ''
as $$
  update public._keepalive set pinged_at = now() where id = 1
  returning pinged_at;
$$;

-- Only the anon role may call it. Worst case abuse is updating a timestamp.
revoke execute on function public.keep_alive() from public;
grant execute on function public.keep_alive() to anon;
