-- BotVote pending-approval email notifications
-- Run once in Supabase SQL Editor. Safe to re-run.
alter table public.botvote_bots
  add column if not exists notification_sent_at timestamptz;

create index if not exists botvote_pending_notification_idx
  on public.botvote_bots(created_at)
  where status = 'pending' and notification_sent_at is null;

-- Enable pg_cron and pg_net in Supabase Dashboard > Database > Extensions.
-- After deploying the Edge Function, configure the recurring call using the
-- separate instructions in supabase/notify-pending-cron.sql.
