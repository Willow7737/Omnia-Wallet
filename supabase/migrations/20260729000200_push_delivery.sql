-- Push delivery: where to send, and what kicks the sending off.
--
-- The notification row is already written by notify_on_reply. This adds the
-- second half — the handsets registered against an account, and an async call
-- out to the send-push edge function whenever a row lands.

create extension if not exists pg_net with schema extensions;

-- One row per handset. A person signed in on a phone and a tablet gets both.
create table if not exists public.device_tokens (
  token       text primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  platform    text not null default 'android'
                check (platform in ('android', 'ios')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.device_tokens is
  'FCM registration tokens. The token is the primary key rather than '
  '(user_id, token): a handset that is signed out and signed back in as '
  'somebody else keeps the same token, and it must move to the new account '
  'rather than notify both.';

create index if not exists device_tokens_user_idx
  on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- A token is a delivery address. Reading somebody else's is not useful on its
-- own, but writing one is: it would redirect their notifications to you.
drop policy if exists "users read their own device tokens" on public.device_tokens;
create policy "users read their own device tokens"
  on public.device_tokens for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "users register their own device" on public.device_tokens;
create policy "users register their own device"
  on public.device_tokens for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "users update their own device" on public.device_tokens;
create policy "users update their own device"
  on public.device_tokens for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "users unregister their own device" on public.device_tokens;
create policy "users unregister their own device"
  on public.device_tokens for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- Kicking off delivery
-- ---------------------------------------------------------------------------

-- The function URL and the key to call it with live in Vault, not here: this
-- file is in git, and a service-role key in git is a total compromise of the
-- project. Create them once with
--
--   select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--   select vault.create_secret('<service-role-key>', 'service_role_key');
--
-- Until both exist, this trigger does nothing at all and replies still work —
-- see the exception block. That is deliberate: a missing push secret must
-- never be able to stop somebody posting a reply.

create or replace function public.deliver_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  project_url text;
  service_key text;
begin
  select decrypted_secret into project_url
  from vault.decrypted_secrets where name = 'project_url';

  select decrypted_secret into service_key
  from vault.decrypted_secrets where name = 'service_role_key';

  if project_url is null or service_key is null then
    return new;
  end if;

  -- Async: pg_net queues the request and returns immediately, so the reply
  -- that caused this is not waiting on Google.
  perform extensions.net.http_post(
    url := project_url || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := jsonb_build_object(
      'notification_id', new.id,
      'user_id', new.user_id,
      'title', new.title,
      'body', new.body,
      'link', new.link,
      'kind', new.kind
    ),
    timeout_milliseconds := 5000
  );

  return new;
exception when others then
  -- A push that could not be dispatched is a worse outcome than a reply that
  -- could not be posted, so this swallows rather than raises. The in-app
  -- notification is already committed either way.
  raise warning 'deliver_push failed: %', sqlerrm;
  return new;
end;
$$;

drop trigger if exists notifications_deliver_push on public.notifications;
create trigger notifications_deliver_push
  after insert on public.notifications
  for each row
  when (new.user_id is not null)
  execute function public.deliver_push();
