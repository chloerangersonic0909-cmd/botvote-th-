-- BotVote Admin Dashboard permissions
-- Run in Supabase SQL Editor as project owner.
-- Assign role using Supabase Dashboard trusted user app_metadata, not user_metadata.

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

-- Restrict client-side update permission to the status column only.
revoke update on public.botvote_bots from anon, authenticated;
grant update (status) on public.botvote_bots to authenticated;

-- IMPORTANT: only set app_metadata.role = admin for the actual administrator
-- in Supabase Dashboard > Authentication > Users. Never set role in user_metadata.
-- After changing app_metadata, sign out and sign back in to refresh the JWT.
