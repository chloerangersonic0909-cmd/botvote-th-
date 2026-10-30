-- BotVote production hardening + persistent reviews migration
-- Run once in Supabase SQL Editor as project owner.
-- Safe to re-run.

create table if not exists public.botvote_reviews (
  id uuid primary key default gen_random_uuid(),
  bot_id uuid not null references public.botvote_bots(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text not null check (char_length(trim(comment)) between 1 and 500),
  created_at timestamptz not null default now(),
  constraint botvote_one_review_per_user_per_bot unique (bot_id, user_id)
);

create index if not exists botvote_reviews_bot_created_idx
  on public.botvote_reviews(bot_id, created_at desc);

alter table public.botvote_reviews enable row level security;

drop policy if exists "BotVote public reads reviews for approved bots" on public.botvote_reviews;
create policy "BotVote public reads reviews for approved bots"
on public.botvote_reviews for select
to anon, authenticated
using (exists (
  select 1 from public.botvote_bots b
  where b.id = bot_id and b.status = 'approved'
));

drop policy if exists "BotVote users review approved bots once" on public.botvote_reviews;
create policy "BotVote users review approved bots once"
on public.botvote_reviews for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.botvote_bots b
    where b.id = bot_id and b.status = 'approved'
  )
);

grant select on public.botvote_reviews to anon, authenticated;
grant insert on public.botvote_reviews to authenticated;

-- Fix moderation read access and limit moderators to status changes only.
grant select on public.botvote_bots to authenticated;
drop policy if exists "BotVote admins read all bots" on public.botvote_bots;
create policy "BotVote admins read all bots"
on public.botvote_bots for select
to authenticated
using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "BotVote admins update bot moderation status" on public.botvote_bots;
create policy "BotVote admins update bot moderation status"
on public.botvote_bots for update
to authenticated
using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

revoke update on public.botvote_bots from anon, authenticated;
grant update (status) on public.botvote_bots to authenticated;

-- A user can only vote once per bot; uniqueness is enforced by the database.
-- Never put a Supabase service_role/secret key in a public website.
