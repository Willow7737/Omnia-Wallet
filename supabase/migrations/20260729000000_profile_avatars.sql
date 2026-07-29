-- Profile pictures, and the storage they live in.
--
-- `user_dids.display_name` already exists and is what the web interface reads
-- and writes, so the avatar joins it there rather than starting a second
-- profile table the two apps would have to keep in step. The DID column is
-- deliberately untouched: it is created at signup, is immutable, and is what
-- mint-node-jwt looks up to mint a node token.

alter table public.user_dids
  add column if not exists avatar_url text;

comment on column public.user_dids.avatar_url is
  'Public URL of the profile picture in the avatars bucket. Null means fall '
  'back to the DID identicon.';

-- A public bucket: an avatar is shown beside replies, so it has to be
-- readable without a token. Writes are the part that needs guarding.
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

-- Each user owns exactly one folder, named for their uid, and may only write
-- inside it. Without the folder check any signed-in user could overwrite
-- anyone else's picture — the bucket is one flat namespace otherwise.
drop policy if exists "avatars are readable by everyone" on storage.objects;
create policy "avatars are readable by everyone"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "users write their own avatar" on storage.objects;
create policy "users write their own avatar"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "users replace their own avatar" on storage.objects;
create policy "users replace their own avatar"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "users delete their own avatar" on storage.objects;
create policy "users delete their own avatar"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
