-- BotVote: invoke the email notification Edge Function every minute.
-- Prerequisites:
-- 1) Deploy supabase/functions/notify-pending/index.ts as "notify-pending".
-- 2) Enable pg_cron and pg_net extensions.
-- 3) Store these secrets in Supabase Vault (Dashboard > Integrations > Vault):
--      project_url = https://crgjfdbdccpqumqaiuyq.supabase.co
--      secret_key = your Supabase service_role/secret key
-- Never put the service key in HTML or commit it to GitHub.

select vault.create_secret(
  'https://crgjfdbdccpqumqaiuyq.supabase.co',
  'project_url'
);

-- Replace the placeholder below with the Supabase service_role/secret key
-- in the SQL editor only. Do not save or commit the real key in this file.
-- select vault.create_secret('PASTE_SERVICE_ROLE_KEY_HERE', 'secret_key');

select cron.schedule(
  'botvote-pending-email-every-minute',
  '* * * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/notify-pending',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'secret_key'),
      'apikey', (select decrypted_secret from vault.decrypted_secrets where name = 'secret_key')
    ),
    body := jsonb_build_object('triggered_at', now()),
    timeout_milliseconds := 10000
  );
  $$
);
