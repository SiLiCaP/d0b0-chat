# d0b0 chat push notifications: server-side setup

For the Claude session that administers the d0b0 server (the one running the
`d0b0.lv` Matrix homeserver). Goal: make push notifications work for the
**d0b0 chat Android app** by self-hosting a UnifiedPush server (**ntfy**).
iOS is a later phase (see the end); do not start it now.

## Background (what the app does)

- d0b0 chat is a FluffyChat fork (repo: `github.com/SiLiCaP/d0b0-chat`, app id
  `lv.d0b0.chat`). On Android it uses **UnifiedPush**: the phone runs the ntfy
  app as its "distributor", the d0b0 chat app gets a push endpoint URL from it,
  and registers a Matrix pusher with the homeserver.
- When a message arrives, **Synapse** POSTs to the pusher's gateway URL
  `https://<ntfy host>/_matrix/push/v1/notify`. ntfy has this Matrix gateway
  built in and forwards the notification to the phone.
- The app checks the gateway with a GET on that same path. If the answer is not
  `{"unifiedpush":{"gateway":"matrix"}}`, it falls back to the public
  `matrix.gateway.unifiedpush.org`. We want our own server to answer correctly
  so no notification passes through third parties.
- The app sends `event_id_only` pushes: no message content goes through ntfy,
  only room and event ids. The phone fetches and decrypts the message itself.

No change to the homeserver's Matrix behaviour is needed, apart from the
outbound-request allowlist in step 4 if it applies.

## Before you start

1. Find out and write down how the server is laid out: OS, whether services run
   in Docker/compose or natively, the reverse proxy (nginx, Caddy, Traefik), and
   how traffic gets in (the owner mentioned a Raspberry Pi tunnel, possibly
   Cloudflare Tunnel). Follow the existing pattern; don't introduce a new one.
2. Back up every config file before you edit it.
3. **Ask the owner before restarting Synapse** or changing DNS or tunnel config.
4. Never commit secrets (ntfy passwords, tokens) to the public d0b0-chat repo.

## Steps

### 1. Pick the hostname

Use `ntfy.d0b0.lv` unless the owner prefers another name. It needs public
HTTPS with a valid certificate, because phones connect to it from anywhere.

### 2. Install ntfy

Official docs: https://docs.ntfy.sh/install/ (Docker image `binwiederhier/ntfy`,
or the apt/deb package; ARM64 builds exist for the Pi).

Minimal `server.yml` (adjust paths to the install method):

```yaml
base-url: "https://ntfy.d0b0.lv"
listen-http: ":2586"            # internal port, the proxy/tunnel terminates TLS
behind-proxy: true
cache-file: "/var/cache/ntfy/cache.db"   # keeps messages while a phone is offline
cache-duration: "12h"
auth-file: "/var/lib/ntfy/user.db"
auth-default-access: "deny-all"
```

Access control: this is a private server for the owner and friends, so keep it
closed but let push gateways write to UnifiedPush topics, which are random
`up…` names. Check the exact recipe against the ntfy docs (search for
"UnifiedPush" on https://docs.ntfy.sh/config/) before applying. The usual
setup:

```sh
ntfy access everyone 'up*' write-only   # Synapse/ntfy gateway can deliver
ntfy user add d0b0                      # one shared login for the phones (owner keeps the password)
ntfy access d0b0 'up*' read-write
```

If the docs say the phone app can read UnifiedPush topics without a login under
this setup, skip the shared user. If locking it down blocks delivery during
testing, fall back to `auth-default-access: "read-write"`. Topic names are
random and unguessable, so that fallback is acceptable. Tell the owner which
one you chose.

### 3. Expose it through the proxy/tunnel

- Route `https://ntfy.d0b0.lv` → ntfy's internal port.
- The ntfy phone app holds a **long-lived connection** (WebSocket or HTTP
  stream). Make sure the proxy allows WebSockets/upgrade and doesn't cut idle
  connections faster than ntfy's 45 s keepalive. Cloudflare Tunnel supports
  this by default.
- Don't put caching or buffering in front of ntfy (for nginx:
  `proxy_buffering off;`, `proxy_read_timeout` of several minutes).

### 4. Make sure Synapse can reach it

Synapse refuses outbound requests to private IP addresses by default
(`ip_range_blacklist`). If `ntfy.d0b0.lv` resolves to a LAN or Docker address
from where Synapse runs, pushes will silently fail. Check from inside the
Synapse host or container:

```sh
curl -sS https://ntfy.d0b0.lv/_matrix/push/v1/notify
```

- If it resolves publicly (e.g. through Cloudflare), nothing to change.
- If it resolves to a private address, add exactly that address or range to
  `ip_range_whitelist` in `homeserver.yaml` (ask the owner first, then restart
  Synapse).

### 5. Verify the server side

```sh
# Matrix gateway discovery: must print {"unifiedpush":{"gateway":"matrix"}}
curl -sS https://ntfy.d0b0.lv/_matrix/push/v1/notify

# Anonymous write to a UnifiedPush-style topic must succeed
curl -sS -d "test" https://ntfy.d0b0.lv/uptest123
```

### 6. Phone setup (tell the owner, they do this on the phone)

1. Install **ntfy** (F-Droid or Play Store).
2. ntfy → Settings → **Default server** → `https://ntfy.d0b0.lv`. If you created
   the shared user, add it under Settings → **Manage users** for that server.
3. Settings → battery: set ntfy to **unrestricted** / not optimised.
4. Install the d0b0 chat APK (from GitHub Releases), log in. It registers with
   ntfy automatically. If it was installed before ntfy, log out and in again,
   or toggle notifications in the app's settings.

### 7. End-to-end check

1. Confirm the pusher exists and points at our server, using the Synapse admin
   API (needs an admin access token, don't store it anywhere):
   `GET /_synapse/admin/v1/users/@<user>:d0b0.lv/pushers`.
   The `data.url` must be `https://ntfy.d0b0.lv/_matrix/push/v1/notify`, not
   `matrix.gateway.unifiedpush.org`.
2. Lock the phone, close the app, send it a message from another account. A
   notification should appear within seconds.
3. If nothing arrives: check the Synapse log for push errors (HTTP failures,
   "rejected" pushkeys, blacklisted IP) and the ntfy log for incoming
   `/_matrix/push/v1/notify` requests.

## Report back to the owner

- The ntfy URL, which access-control option you used, and the shared login if
  any (tell them directly, not in the repo).
- Whether `ip_range_whitelist` was changed.
- The result of the step 5 and step 7 checks.

## Later: iOS (planned, do not start)

iOS can't use UnifiedPush; Apple only delivers push through APNs. When the
owner starts iOS testing, the server side will need a **Sygnal** push gateway
(the Matrix.org push gateway), e.g. at `push.d0b0.lv`, configured with app id
`lv.d0b0.chat` and Firebase/APNs credentials. Prerequisites are on the owner's
side first: a paid Apple Developer account, an APNs key, and a Firebase
project. The app will then be pointed at `push.d0b0.lv` instead of FluffyChat's
`push.fluffychat.im`. Nothing to set up for this yet. At most, keep the
`push.d0b0.lv` name free.
