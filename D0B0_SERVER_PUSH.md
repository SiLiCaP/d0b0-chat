# d0b0 chat push notifications

**Decision (2026-10-25): no extra app on the phone.** d0b0 chat does what
WhatsApp, Signal, Discord and Telegram do — the platform's own push channel
(**FCM** on Android, **APNs** on iOS) through **our own Matrix push gateway,
Sygnal, at `push.d0b0.lv`**. UnifiedPush stays in the app as the fallback for
phones without Google services. Phase **B (optional, later)**: the app's own
background connection for de-Googled phones, so no distributor app is needed
there either. (The earlier ntfy plan is dropped: it needed the ntfy app.)

## How a notification travels

```
message → Synapse ─POST /_matrix/push/v1/notify─▶ Sygnal (push.d0b0.lv, our host)
                                                     │  event_id_only: room + event id, no text
                                                     ▼
                                          Google FCM (Android) / Apple APNs (iOS, later)
                                                     │
                                                     ▼
                       d0b0 chat wakes, fetches + decrypts the event itself, shows the notification
```

Google/Apple only learn "there is something for this device". Extra data we
add later must stay metadata — never message content.

## Server side (d0b0-domain repo, done 2026-10-25)

- `services/push/` — Sygnal in Docker (`d0b0-push`, `127.0.0.1:5005`),
  tunnel route + DNS for `push.d0b0.lv`. Config and the Firebase
  service-account key live in `/srv/projects/secrets/d0b0.lv/push` on the
  host, never in git. `bash setup.sh` writes `sygnal.yaml` from the key's
  project id and starts it.
- Sygnal's app key is the glob **`lv.d0b0.chat*`**: the app registers each pusher as `lv.d0b0.chat.<matrix device id>` (`background_push.dart`). With an exact `lv.d0b0.chat` key every push came back "unknown app ID" → rejected → Synapse deleted the pusher.
- **End-to-end test passed 2026-10-25** (Android, locked phone, app closed).
- Synapse needs no change: it reaches `push.d0b0.lv` through Cloudflare
  (public addresses), and no outbound IP filter applies.

## App side (this repo, branch `feat/fcm-push`)

- Default gateway: `https://push.d0b0.lv/_matrix/push/v1/notify`
  (`setting_keys.dart`), pusher format `event_id_only` (unchanged).
- FCM is switched on at build time, FluffyChat-style: CI writes
  `android/app/google-services.json` from the **`GOOGLE_SERVICES_JSON`**
  secret (base64) and runs `scripts/add-firebase-messaging.sh`. Without the
  secret the APK is Google-free (UnifiedPush only). The JSON is gitignored.
- Local build with FCM: put `google-services.json` in `android/app/`, run
  `./scripts/add-firebase-messaging.sh`, `flutter build apk` — and don't
  commit the script's changes.

## Setup checklist

1. Firebase project `d0b0-chat`, Android app `lv.d0b0.chat` →
   `google-services.json` (app build) + service-account key (host secrets).
2. Host: key → `/srv/projects/secrets/d0b0.lv/push/fcm-service-account.json`,
   `bash services/push/setup.sh`, `curl https://push.d0b0.lv/health` → `OK`.
3. GitHub: secret `GOOGLE_SERVICES_JSON` = `base64 -i google-services.json`.
4. Build, install, log in; check the pusher
   (`GET /_synapse/admin/v1/users/@<user>:d0b0.lv/pushers` → `data.url` is
   push.d0b0.lv, `app_id` `lv.d0b0.chat`); lock the phone, send a message.

## iOS (later)

APNs key from a paid Apple Developer account → a second app in Sygnal
(`type: apns`, topic `lv.d0b0.chat`); the same gateway serves both.
