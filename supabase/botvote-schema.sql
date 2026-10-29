-- BotVote shared database (safe to run in Supabase SQL Editor)
-- Uses prefixed table names so it won't conflict with other apps in this Supabase project.

create table if not exists public.botvote_bots (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  client_id text not null unique check (client_id ~ '^[0-9]{15,24}$'),
  invite_url text not null check (invite_url like 'https://discord.com/oauth2/authorize%' or invite_url like 'https://discordapp.com/oauth2/authorize%'),
  description text not null check (char_length(description) between 1 and 500),
  tags text[] not null default '{}',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  likes_count integer not null default 0 check (likes_count >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.botvote_votes (
  id uuid primary key default gen_random_uuid(),
  bot_id uuid not null references public.botvote_bots(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint botvote_one_vote_per_user_per_bot unique (bot_id, user_id)
);

create index if not exists botvote_bots_public_listing_idx on public.botvote_bots(status, created_at desc);
create index if not exists botvote_votes_user_idx on public.botvote_votes(user_id);

alter table public.botvote_bots enable row level security;
alter table public.botvote_votes enable row level security;

drop policy if exists "BotVote public reads approved bots" on public.botvote_bots;
create policy "BotVote public reads approved bots"
on public.botvote_bots for select
to anon, authenticated
using (status = 'approved' or owner_id = (select auth.uid()));

drop policy if exists "BotVote authenticated users submit own bots" on public.botvote_bots;
create policy "BotVote authenticated users submit own bots"
on public.botvote_bots for insert
to authenticated
with check (owner_id = (select auth.uid()) and status = 'pending');

drop policy if exists "BotVote users read own votes" on public.botvote_votes;
create policy "BotVote users read own votes"
on public.botvote_votes for select
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "BotVote users vote once on approved bots" on public.botvote_votes;
create policy "BotVote users vote once on approved bots"
on public.botvote_votes for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.botvote_bots b
    where b.id = bot_id and b.status = 'approved'
  )
);

create or replace function public.botvote_increment_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.botvote_bots
  set likes_count = likes_count + 1
  where id = new.bot_id and status = 'approved';
  if not found then
    raise exception 'Bot is not available for voting';
  end if;
  return new;
end;
$$;

drop trigger if exists botvote_vote_increments_like on public.botvote_votes;
create trigger botvote_vote_increments_like
after insert on public.botvote_votes
for each row execute function public.botvote_increment_like();

grant select on public.botvote_bots to anon, authenticated;
grant insert on public.botvote_bots to authenticated;
grant select, insert on public.botvote_votes to authenticated;
