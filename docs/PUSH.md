# Push notifications — setup

The app ships the whole pipeline. Two credentials are missing, and both can
only be created by someone with access to the Firebase and Supabase consoles.

**Until they exist, nothing breaks.** The build succeeds, the app runs, and
replies still appear in the Notifications tab — they just do not reach the lock
screen. Every piece below fails soft on purpose:

| Missing | What happens |
|---|---|
| `android/app/google-services.json` | The google-services Gradle plugin is not applied, `Firebase.initializeApp()` throws, `PushService` logs and disables itself. |
| `FCM_SERVICE_ACCOUNT` function secret | `send-push` returns `{"skipped": …}` with HTTP 200. |
| `project_url` / `service_role_key` Vault secrets | The `deliver_push` trigger returns without calling anything. |

---

## 1. Firebase project and `google-services.json`

1. Create a Firebase project (or reuse one) at <https://console.firebase.google.com>.
2. **Add app → Android.** The package name must be exactly `com.omnia.wallet`.
3. Download `google-services.json` and put it at `android/app/google-services.json`.

`android/app/google-services.json` is gitignored — it is per-project
configuration, not source. Anyone building a release needs their own copy.

Verify: `flutter build apk` prints the "building without push notifications"
line when the file is missing, and does not print it when it is present.

## 2. FCM service account → Supabase function secret

1. Firebase console → **Project settings → Service accounts → Generate new
   private key**. This downloads a JSON file.
2. Store it as a function secret:

   ```
   supabase secrets set FCM_SERVICE_ACCOUNT="$(cat ~/Downloads/service-account.json)" \
     --project-ref iyajzmgnykgkivabxiuw
   ```

That JSON is a credential for the whole Firebase project. It belongs in
function secrets and nowhere else — never in the repo, never in the app.

## 3. Vault secrets, so the database can call the function

Run once, in the SQL editor:

```sql
select vault.create_secret('https://iyajzmgnykgkivabxiuw.supabase.co', 'project_url');
select vault.create_secret('<your service_role key>', 'service_role_key');
```

The service-role key is why `send-push` is deployed with `verify_jwt` off: the
caller is the database, not a signed-in user, so the function checks the key
itself and returns 403 to everything else.

## 4. Deploy the function

Already deployed. To redeploy after changes:

```
supabase functions deploy send-push --project-ref iyajzmgnykgkivabxiuw --no-verify-jwt
```

---

## How a reply becomes a notification

```
someone posts a reply
   └─ news_replies INSERT
        └─ trigger notify_on_reply()        [SECURITY DEFINER]
             └─ notifications INSERT         → in-app feed, via realtime
                  └─ trigger deliver_push()  [pg_net, async]
                       └─ POST /functions/v1/send-push
                            └─ device_tokens lookup → FCM v1 → the handset
```

The in-app half and the push half are deliberately independent. A push that
cannot be sent — no Firebase, no network, a dead token — leaves the
notification sitting in the feed where the reader will find it. A reply is
never blocked by either.

### Who gets notified

The author of the reply being answered. Not yourself (replying to your own
comment notifies nobody), and not the author of a top-level comment on a news
post — those posts are written by the team under a text author with no account
behind it.

## Checking it works

```sql
-- Is a handset registered?
select user_id, platform, updated_at from device_tokens;

-- Did the trigger fire? pg_net records every request it made.
select id, url, status_code, created
from net._http_response order by created desc limit 5;
```

A `status_code` of 200 with `{"sent": 0}` means the pipeline is working and no
device is registered for that user. `{"skipped": …}` means step 2 is not done.
No row at all means step 3 is not done.

## Notes

- The Android channel id is `omnia_replies` in three places that must agree:
  `AndroidManifest.xml`, `PushService._channelId`, and the `channel_id` in the
  edge function. A mismatch files notifications under a channel the reader
  cannot find in system settings.
- Android does not display a notification while the app is in the foreground.
  `PushService` draws one itself with `flutter_local_notifications`, keyed on
  the link so several replies to one conversation collapse into a row rather
  than stacking.
- Signing out deletes this handset's token, so a shared phone stops receiving
  the previous account's replies.
- Tokens that FCM reports as `UNREGISTERED` are deleted by the edge function,
  so the table does not grow a tail of uninstalled apps.
- iOS needs an APNs key uploaded to Firebase before any of this works there;
  the app side is already in place.
