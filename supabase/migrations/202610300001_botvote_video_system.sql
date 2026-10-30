-- BotVote community video system
-- Run this entire file in Supabase Dashboard > SQL Editor > New query.
create extension if not exists pgcrypto;

create table if not exists public.botvote_videos (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 100),
  youtube_id text not null check (youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
  owner_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  likes_count integer not null default 0,
  ratings_count integer not null default 0,
  rating_average numeric(3,2) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.botvote_video_likes (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.botvote_videos(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(video_id, user_id)
);

create table if not exists public.botvote_video_ratings (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.botvote_videos(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(video_id, user_id)
);

alter table public.botvote_videos enable row level security;
alter table public.botvote_video_likes enable row level security;
alter table public.botvote_video_ratings enable row level security;

drop policy if exists "Approved videos are viewable by everyone" on public.botvote_videos;
create policy "Approved videos are viewable by everyone"
on public.botvote_videos for select to anon, authenticated
using (status = 'approved' or owner_id = auth.uid());

drop policy if exists "Signed-in users can submit videos" on public.botvote_videos;
create policy "Signed-in users can submit videos"
on public.botvote_videos for insert to authenticated
with check (owner_id = auth.uid() and status = 'pending');

drop policy if exists "Users can view likes on approved videos" on public.botvote_video_likes;
create policy "Users can view likes on approved videos"
on public.botvote_video_likes for select to anon, authenticated
using (exists (select 1 from public.botvote_videos v where v.id = video_id and v.status = 'approved'));

drop policy if exists "Users can like approved videos as themselves" on public.botvote_video_likes;
create policy "Users can like approved videos as themselves"
on public.botvote_video_likes for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.botvote_videos v where v.id = video_id and v.status = 'approved'));

drop policy if exists "Users can view ratings on approved videos" on public.botvote_video_ratings;
create policy "Users can view ratings on approved videos"
on public.botvote_video_ratings for select to anon, authenticated
using (exists (select 1 from public.botvote_videos v where v.id = video_id and v.status = 'approved'));

drop policy if exists "Users can rate approved videos as themselves" on public.botvote_video_ratings;
create policy "Users can rate approved videos as themselves"
on public.botvote_video_ratings for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.botvote_videos v where v.id = video_id and v.status = 'approved'));

drop policy if exists "Users can update their own video ratings" on public.botvote_video_ratings;
create policy "Users can update their own video ratings"
on public.botvote_video_ratings for update to authenticated
using (user_id = auth.uid() and exists (select 1 from public.botvote_videos v where v.id = video_id and v.status = 'approved'))
with check (user_id = auth.uid() and exists (select 1 from public.botvote_videos v where v.id = video_id and v.status = 'approved'));

create or replace function public.botvote_refresh_video_counts(target_video_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.botvote_videos v
  set likes_count = (select count(*)::integer from public.botvote_video_likes l where l.video_id = target_video_id),
      ratings_count = (select count(*)::integer from public.botvote_video_ratings r where r.video_id = target_video_id),
      rating_average = coalesce((select round(avg(r.rating)::numeric, 2) from public.botvote_video_ratings r where r.video_id = target_video_id), 0)
  where v.id = target_video_id;
end;
$$;

create or replace function public.botvote_video_likes_count_trigger()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.botvote_refresh_video_counts(coalesce(new.video_id, old.video_id));
  return coalesce(new, old);
end;
$$;

create or replace function public.botvote_video_ratings_count_trigger()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.botvote_refresh_video_counts(coalesce(new.video_id, old.video_id));
  return coalesce(new, old);
end;
$$;

drop trigger if exists botvote_video_likes_count_update on public.botvote_video_likes;
create trigger botvote_video_likes_count_update
after insert or delete on public.botvote_video_likes
for each row execute function public.botvote_video_likes_count_trigger();

drop trigger if exists botvote_video_ratings_count_update on public.botvote_video_ratings;
create trigger botvote_video_ratings_count_update
after insert or update or delete on public.botvote_video_ratings
for each row execute function public.botvote_video_ratings_count_trigger();

grant select on public.botvote_videos, public.botvote_video_likes, public.botvote_video_ratings to anon, authenticated;
grant insert on public.botvote_videos, public.botvote_video_likes, public.botvote_video_ratings to authenticated;
grant update on public.botvote_video_ratings to authenticated;
