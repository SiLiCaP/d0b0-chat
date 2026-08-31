# d0b0 chat — kickoff for a fresh Claude session

You're in a **fork of [FluffyChat](https://github.com/krille-chan/fluffychat)**
(Flutter, AGPLv3). The mission: turn it into **d0b0 chat** — **one** app that
runs on Android, iOS, desktop, and web from a **single codebase**, styled in the
d0b0 green theme, talking to the private `d0b0.lv` Matrix homeserver.

This replaces an earlier plan that used two separate native forks (Element X for
Android + iOS). We deliberately pivoted to Flutter because the goal is a
**Discord-like single universal interface** that's **simple to manage when Claude
does the work** — one repo, one language, add-a-feature-once, ships everywhere.
The two native repos are being retired.

> This checkout also has FluffyChat's own `README.md`/`CONTRIBUTING.md` — their
> build/dev docs, genuinely useful. This file is the d0b0 layer on top.

---

## Why Flutter (decisions locked — don't relitigate)

- **One codebase, all platforms.** Flutter compiles `lib/` to *native* on
  Android/iOS/macOS/Windows/Linux and to the web (not a webview) — the same UI
  everywhere. This IS the "universal core + platform quirks" architecture the
  owner wanted; Flutter gives it to you as the default project layout.
- **Fork FluffyChat**, don't start from scratch — it's the mature AGPL Flutter
  Matrix client (E2EE, cross-signing, key backup, spaces, push, voice).
- **One public repo** (`d0b0-chat`), AGPLv3 (inherited). Keep FluffyChat as an
  `upstream` remote to pull updates.
- **Client only.** The homeserver needs no changes — the one exception is QR
  login (see that section), which is a later, optional, server-touching feature.

## The architecture (this answers "a skeleton you pour platform quirks into")

That's exactly what a Flutter repo is. You do **not** build the skeleton — it
*is* the skeleton:

```
d0b0-chat/                 ← ONE repo
├── lib/                   ← UNIVERSAL: every screen, widget, all logic, the theme — written ONCE
├── config.json            ← branding + homeserver + theme seed (copy of config.sample.json)
├── android/               ← Android shell + quirks only (FCM/UnifiedPush, manifest, bundle id)
├── ios/                   ← iOS shell + quirks only (APNs, Info.plist, entitlements, bundle id)
├── macos/ windows/ linux/ ← desktop shells
├── web/                   ← web build target
├── assets/                ← icons, images (d0b0 branding goes here)
└── pubspec.yaml           ← one dependency list
```

Everything in `lib/` is written once. Genuine OS-specific quirks (push tokens,
notification display, share sheet, camera/files, background work) are reached
through Flutter **plugins / platform channels** — small, well-defined seams into
the `android/`/`ios/` folders. **Use subfolders in this one repo, not separate
repos per platform** — separate repos fragment the shared code and make a
one-change-affects-all edit painful. Flutter's layout already draws the line in
the right place.

## Rebrand (mostly one JSON file + a couple of constants)

1. **`config.json`** — copy `config.sample.json` → `config.json` and set:
   - `applicationName`: `"d0b0 chat"`
   - `defaultHomeserver` + `presetHomeserver`: `"d0b0.lv"` (delegation resolves
     it to `chat.d0b0.lv`; a preset skips the "choose a homeserver" step)
   - `colorSchemeSeedInt`: the d0b0 green seed (see Theme) — `4282374191`
   - `separateChatTypes` is already `false` = unified DM+group list (the
     Discord-like inbox) — good, leave it.
2. **`lib/config/app_config.dart`** — `primaryColor = Color(0xFF261386)`
   (FluffyChat purple) → `Color(0xFF3FD82F)` (d0b0 green).
3. **App/bundle ids + display name:** in `android/app/build.gradle`
   (`applicationId`) and the iOS Xcode project (`PRODUCT_BUNDLE_IDENTIFIER`),
   plus the display-name strings. Suggested id: `lv.d0b0.chat`.
4. **Icons/splash:** replace under `assets/` (FluffyChat uses
   `flutter_launcher_icons` / `flutter_native_splash` — see its config).
5. Keep AGPL/REUSE license headers; the repo stays public.

## Theme (d0b0 green `#3fd82f`)

FluffyChat uses **Material 3 seed-based theming**
(`ColorScheme.fromSeed(...)` in `lib/config/themes.dart`), so you set **one seed
color** and Flutter derives the full light+dark schemes. Set the seed to green:
`Color(0xFF3FD82F)` (= `colorSchemeSeedInt: 4282374191`). That alone gets you a
coherent green app in both light and dark. Then hand-tune specifics against the
existing Element Web "d0b0" theme so desktop and mobile match — the exact token
palette is in the **appendix at the bottom** so you don't need the infra repo.

Colour family (each d0b0 service owns one; **chat is green**): coin `#d0b000`,
upload `#00d0b0`, panel `#b000d0`, hephaestus `#dd0b00`, **chat `#3fd82f`**.

## The Matrix SDK caveat (read before promising fancy features)

FluffyChat is built on the **Dart** Matrix SDK (`matrix: ^11`, famedly), **not**
Element X's Rust SDK. It's solid — E2EE, cross-signing, encrypted key backup,
spaces, push all work. But it can lag the Rust SDK on the newest things. So
**before designing on top of them, verify current Dart-SDK support for:**
sliding sync / simplified sliding sync, and **QR-code login (MSC4108)**. Assume
they might not be there yet and plan a fallback.

## What you get for free (FluffyChat baseline — don't rebuild)

Unified DM+group chat list, spaces (nestable), E2EE + cross-signing + encrypted
key backup, device verification (emoji/QR *verify*), push via **FCM or
UnifiedPush**, image/file/voice messages, experimental voice/video, and it
already builds for every platform. So the "better sorting / unified inbox" wish
is largely the default here — first jobs are rebrand + theme, then *new*
features on top.

## The web interface

**You get web for free** from the same repo (the `web/` build target) — the same
UI as mobile, which is the most consistent, Discord-like outcome and nothing
extra to maintain. Plan:
- Keep the **existing Element Web** (already themed, deployed at `chat.d0b0.lv`)
  running as-is until the Flutter web build is good enough to replace it.
- When ready, build `flutter build web` and host it (its own subdomain or route
  via the RPi tunnel); "linking" is just DNS/tunnel + pointing at it. Decide
  later whether it *replaces* Element Web at `chat.d0b0.lv` or lives beside it.
- Caveat: Flutter web has a heavier initial load than a hand-tuned React app —
  fine for a logged-in chat client, worth a look before making it the primary.

## Discord-style "update on open" (per platform)

- **Android (sideloaded APK):** yes — the app can check a URL for a newer version
  and prompt an in-app install (the F-Droid / self-distribution pattern). Needs
  the "install unknown apps" permission. **Useful** since you're distributing
  outside Play; worth adding — but as a **v2** item, after the app works.
- **Desktop:** yes — a check-download-relaunch updater is doable.
- **iOS:** **no.** Apple forbids apps self-updating / downloading executable
  code; updates go through TestFlight or the App Store. Don't design around it.
- **Web:** free — it's always the latest served build.
- *Code-push* (OTA Dart changes, à la "Shorebird") exists for Flutter but is
  Android-solid / iOS-constrained by Apple policy — research before relying on
  it; not needed for v1.

## QR-code login (log in on web by scanning from the phone — great UX idea)

This is a real, standard-track Matrix feature, not something to invent:
**"sign in with QR code" = MSC4108**, built on next-gen OIDC auth. The catch:
- It needs the **homeserver** running next-gen auth
  (**matrix-authentication-service**) — the one server-side change in this whole
  project. And the Dart SDK must implement it (verify — see the SDK caveat).
- **Interim UX that needs no server change and largely solves your pain:** the
  new device logs in, then is **verified from the phone** (emoji/QR *verify*) and
  restores keys from **encrypted key backup** — so the user doesn't re-type the
  long recovery key on every device. That's already in FluffyChat.
- **Sequencing:** build the app first on password login + device-verify + key
  backup. Add QR *login* later as a v2 feature, once the app is stable and you've
  decided to stand up matrix-authentication-service on the homeserver.

## First tasks (suggested order)

1. **Build it unmodified** (`flutter pub get`, then run on an emulator/device;
   see FluffyChat's README for toolchain). Get a baseline before changing things.
2. **Rebrand + theme + homeserver** (config.json, primaryColor, ids, icons).
   Rebuild; confirm it logs into a `d0b0.lv` account and E2EE works.
3. **Verify the SDK caveats** (sliding sync, QR login availability) so you know
   what's on the table.
4. **Feature wishlist** — get specifics from the owner beyond the FluffyChat
   baseline (which already covers the unified inbox/sorting).
5. **Web build** once mobile is solid; then updates + QR login as v2.

## Distribution

- **Android:** hand out the signed APK, or a small personal F-Droid repo. Easy.
- **iOS:** needs an Apple Developer account + Xcode on the Mac — TestFlight (up
  to 10k testers) or sideload (free account = 7-day re-sign). Building is fine on
  the Mac; only distribution needs the account. Unchanged by the framework.
- **Desktop/web:** optional; both build from this repo.

## GitHub setup (do this once)

`gh` isn't installed on the machine — create the repo via the web (or
`brew install gh`). See the owner-facing instructions the assistant gave
alongside this doc for repo name and settings. Wire it up without clobbering
`upstream`:
```bash
git remote add origin https://<PAT>@github.com/SiLiCaP/d0b0-chat.git
git push -u origin main
```
Keep `upstream` → FluffyChat for pulling updates (`git fetch upstream && git merge upstream/main`).

## Retiring the old repos

The two native-fork repos (Android + iOS from the earlier plan) are obsolete —
delete them on GitHub. The local SchildiChat clone the assistant made has
already been removed. Nothing meaningful is lost; the pivot happened before any
of that was verified.

## Guardrails

- Keep AGPLv3 + REUSE/SPDX headers and attribution intact; add ours only to files
  we author. Don't ship FluffyChat's name/trademark in a distributed build.
- Repo is public → **never commit secrets** (signing keystore, PATs, homeserver
  admin creds).
- Client only — never assume you can change the homeserver from here (except the
  deliberate, later QR-login/OIDC work).

---

## Appendix — exact d0b0 theme palette (from the deployed Element Web theme)

Accent green `#3fd82f` (dark) / `#1f9915` (light). Set the Material 3 **seed** to
the dark accent and derive; use these to hand-tune. Brand string: "d0b0 chat".

**Dark (default):** canvas `#060d06`, surface `#0a140a`, subtle `#143314`,
accent/primary `#3fd82f` (hover `#4fff2f`, pressed `#2fae23`), text `#dfe8df`,
text-secondary `#8a9a8a`, on-accent `#041004`, border `#2a3a2a`/`#1c2a1c`.

**Light:** canvas `#f7fbf6`, surface `#edf6eb`, subtle `#d2ecce`, accent/primary
`#1f9915` (hover `#187a10`, pressed `#146a0d`), text `#182018`, text-secondary
`#54644f`, on-accent `#ffffff`, border `#c2dcbe`/`#dae8d8`.

Username/avatar colours cycle the d0b0 family: `#3fd82f #00d0b0 #d0b000 #b000d0 …`.
