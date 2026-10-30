-- BotVote community video voting tables
-- Run once in Supabase SQL Editor for project crgjfdbdccpqumqaiuyq.
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
  unique(video_id,user_id)
);

create table if not exists public.botvote_video_ratings (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.botvote_videos(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(video_id,user_id)
);

alter table public.botvote_videos enable row level security;
alter table public.botvote_video_likes enable row level security;
alter table public.botvote_video_ratings enable row level security;

drop policy if exists "Anyone can view approved videos" on public.botvote_videos;
create policy "Anyone can view approved videos" on public.botvote_videos for select using (status = 'approved' or owner_id = auth.uid());
drop policy if exists "Signed in users can submit videos" on public.botvote_videos;
create policy "Signed in users can submit videos" on public.botvote_videos for insert to authenticated with check (owner_id = auth.uid() and status = 'pending');
drop policy if exists "Users can view own video likes" on public.botvote_video_likes;
create policy "Users can view own video likes" on public.botvote_video_likes for select to authenticated using (user_id = auth.uid());
drop policy if exists "Users can like videos once" on public.botvote_video_likes;
create policy "Users can like videos once" on public.botvote_video_likes for insert to authenticated with check (user_id = auth.uid() and exists(select 1 from public.botvote_videos v where v.id = video_id and v.status = 'approved'));
drop policy if exists "Ratings visible to everyone" on public.botvote_video_ratings;
create policy "Ratings visible to everyone" on public.botvote_video_ratings for select using (true);
drop policy if exists "Users can rate approved videos" on public.botvote_video_ratings;
create policy "Users can rate approved videos" on public.botvote_video_ratings for insert to authenticated with check (user_id = auth.uid() and exists(select 1 from public.botvote_videos v where v.id = video_id and v.status = 'approved'));
drop policy if exists "Users can update own rating" on public.botvote_video_ratings;
create policy "Users can update own rating" on public.botvote_video_ratings for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.botvote_refresh_video_likes()
returns trigger language plpgsql security definer set search_path = public as $$
declare target_id uuid;
begin
  target_id := coalesce(new.video_id, old.video_id);
  update public.botvote_videos set likes_count = (select count(*) from public.botvote_video_likes where video_id = target_id) where id = target_id;
  return coalesce(new, old);
end; $$;
drop trigger if exists botvote_video_likes_count on public.botvote_video_likes;
create trigger botvote_video_likes_count after insert or delete on public.botvote_video_likes for each row execute function public.botvote_refresh_video_likes();

create or replace function public.botvote_refresh_video_rating()
returns trigger language plpgsql security definer set search_path = public as $$
declare target_id uuid;
begin
  target_id := coalesce(new.video_id, old.video_id);
  update public.botvote_videos
  set ratings_count = (select count(*) from public.botvote_video_ratings where video_id = target_id),
      rating_average = coalesce((select round(avg(rating)::numeric,2) from public.botvote_video_ratings where video_id = target_id),0)
  where id = target_id;
  return coalesce(new, old);
end; $$;
drop trigger if exists botvote_video_ratings_count on public.botvote_video_ratings;
create trigger botvote_video_ratings_count after insert or update or delete on public.botvote_video_ratings for each row execute function public.botvote_refresh_video_rating();
