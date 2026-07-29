-- "Someone replied to you", written where the reply is written.
--
-- The alternative — having each client notice replies addressed to it — only
-- works for a client that is running and looking. A row written by the
-- database is there when the app next opens, is the same row every device
-- sees, and is what a push sender can read.

create or replace function public.notify_on_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  parent_author uuid;
  who text;
begin
  -- Only a reply to a reply has somebody to notify. A top-level comment
  -- answers a news post, and those are written by the team under a text
  -- author with no account behind it.
  if new.parent_id is null then
    return new;
  end if;

  select user_id into parent_author
  from public.news_replies
  where id = new.parent_id;

  -- Nobody to tell, or you are replying to yourself. Neither is a
  -- notification; the second is the more annoying of the two.
  if parent_author is null or parent_author = new.user_id then
    return new;
  end if;

  who := coalesce(nullif(btrim(new.author_name), ''), 'Someone');

  insert into public.notifications (user_id, kind, title, body, link)
  values (
    parent_author,
    'reply',
    who || ' replied to you',
    left(new.body, 140),
    -- The post is what opens; the client reads the id off the end. Kept as a
    -- path rather than a bare id so the web interface can follow it directly.
    '/post/' || new.post_id::text
  );

  return new;
end;
$$;

comment on function public.notify_on_reply() is
  'Writes a notifications row for the author of the reply being answered. '
  'SECURITY DEFINER because notifications has no INSERT policy — clients must '
  'not be able to write notifications to each other.';

drop trigger if exists news_replies_notify on public.news_replies;
create trigger news_replies_notify
  after insert on public.news_replies
  for each row execute function public.notify_on_reply();

-- Reading your own notifications is already covered. Deleting them is not,
-- and the app offers a "clear all".
drop policy if exists "Users can delete own notifications" on public.notifications;
create policy "Users can delete own notifications"
  on public.notifications for delete
  using ((select auth.uid()) = user_id);

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc);
