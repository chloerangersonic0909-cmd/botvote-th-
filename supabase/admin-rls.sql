-- BotVote Admin Dashboard RLS migration
-- Run this in Supabase SQL Editor as the project owner.
-- Authorization uses server-managed app_metadata, never user_metadata.

grant select, update on public.botvote_bots to authenticated;

drop policy if exists "BotVote admins update bot moderation status" on public.botvote_bots;
create policy "BotVote admins update bot moderation status"
on public.botvote_bots
for update
to authenticated
using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Then in Supabase Dashboard > Authentication > Users, open your own user
-- and set app_metadata to {"role":"admin"} using the trusted dashboard controls.
-- Do not set this in user_metadata. Do not expose service_role keys in frontend code.
