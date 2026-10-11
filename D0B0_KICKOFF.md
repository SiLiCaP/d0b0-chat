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

1. ✅ **Build it unmodified** — **done 2026-08-31**: the untouched fork ran on
   the iPhone 17 Pro simulator. What it took is under *Build status & toolchain
   notes* below.
2. **Rebrand + theme + homeserver** (config.json, primaryColor, ids, icons).
   Rebuild; confirm it logs into a `d0b0.lv` account and E2EE works.
3. **Verify the SDK caveats** (sliding sync, QR login availability) so you know
   what's on the table.
4. **Feature wishlist** — get specifics from the owner beyond the FluffyChat
   baseline (which already covers the unified inbox/sorting).
5. **Web build** once mobile is solid; then updates + QR login as v2.

## Build status & toolchain notes (the Mac)

Installed 2026-08-31 on the owner's Mac (Apple Silicon, macOS 26, Xcode 26.6):

- **Flutter 3.47.2** (the version `.tool_versions.yaml` pins) at
  `~/development/flutter` — **not on PATH**; before building run
  `export PATH="$HOME/development/flutter/bin:$HOME/.cargo/bin:$PATH"`.
- **Rust** stable (rustup), **CocoaPods**, **cmake + ninja**, **sqlcipher**
  (Homebrew). Rust compiles the vodozemac E2EE crate on every native build;
  cmake builds `webcrypto`'s BoringSSL (CI runners have it preinstalled, so
  upstream never lists it).
- **Still missing:** Android SDK/Studio + JDK 17 (for local Android builds and
  emulators — CI builds the APK meanwhile) and Chrome (for `flutter run -d chrome`).

Gotchas found on the way (none needed a repo change):

1. **The repo path contains a space** (`Creative Projects`). `native_imaging`'s
   podspec emits unquoted include paths, so Xcode mangles them. Patched in the
   *pub cache* (`~/.pub-cache/hosted/pub.dev/native_imaging-<ver>/ios/native_imaging.podspec`:
   quote both `HEADER_SEARCH_PATHS` entries), then `pod install` in `ios/`.
   `dart pub cache repair` or a version bump reverts it — re-apply. The durable
   fix is moving the repo to a space-free path.
2. **Run with `flutter run -d <device>`, not `flutter build ios --simulator`.**
   The latter builds a universal simulator binary and the x86_64 slice fails in
   BoringSSL (`fiat_p256_adx` symbols). Device and release builds are arm64-only
   and unaffected.
3. **`flutter run -d macos` fails unmodified** — upstream hardcodes its Apple
   team (`4NXF6Z997G`) in `macos/Runner.xcodeproj`. Fixed as part of the rebrand.

Quick start: `flutter devices`, then `flutter run -d <id>` (iPhone 17 Pro
simulator: `DA60B980-1996-4D88-B196-532ADD6D2770`).

## Test devices

- **Mac (Apple Silicon)** — builds every target except Windows; iOS simulators
  (iOS 26.5). This is the one dev machine; don't split development across OSes.
- **iPhone XS, iOS 18.7.10** (physical). The app's minimum is iOS 15.6 (notification
  extension 18.5), so it fits. Installing on it needs Apple signing: a free
  Apple ID "personal team" (app re-signs every 7 days) or a paid Developer
  account (TestFlight).
- **Windows PC** — for trying the CI-built Windows desktop app later; not a dev
  machine (it can't build the Apple targets).
- **Android phone** — owner reports one is available; note model/Android version
  here when Android work starts.

## CI & where the working app lands (the produced-content folders)

**Locally** everything lands under `build/` (gitignored):

| Target  | Command                                                     | Output folder                                   |
|---------|-------------------------------------------------------------|-------------------------------------------------|
| Android | `flutter build apk --debug` (`--release` needs a keystore)  | `build/app/outputs/flutter-apk/app-*.apk`       |
| iOS     | `flutter run -d <device>` / `flutter build ios --no-codesign` | `build/ios/iphoneos/Runner.app` (sim: `build/ios/iphonesimulator/`) |
| Web     | `./scripts/prepare-web.sh && flutter build web --release`   | `build/web/` (serve as static files)            |
| macOS   | `flutter build macos` (after the signing-team change)       | `build/macos/Build/Products/Release/*.app`      |
| Linux   | `flutter build linux`                                       | `build/linux/x64/release/bundle/`               |
| Windows | `scripts/build-windows.ps1` (on Windows or CI)              | `build/windows/x64/runner/Release/`             |

**CI** — `.github/workflows/d0b0-ci.yaml`, runs on every push to `main`, every
pull request, manually (*Actions → d0b0 chat CI → Run workflow*), and on `v*` tags:

- Jobs: `checks` (format, analyze, test) → `android` (APK), `web`, `linux`,
  `ios` (unsigned compile check).
- **Every run:** GitHub → *Actions* → the run → **Artifacts**:
  `d0b0-chat-android-apk`, `d0b0-chat-web`, `d0b0-chat-linux-x64`,
  `d0b0-chat-ios-unsigned`.
- **Releases:** `git tag v0.1.0 && git push --tags` → the APK, web zip and Linux
  tarball are attached to **GitHub → Releases**. That release page is the
  canonical place to get the working app.
- **Signed Android release** (recommended before handing APKs out): generate a
  keystore once — `keytool -genkey -v -keystore d0b0-release.jks -keyalg RSA
  -keysize 2048 -validity 10000 -alias d0b0` — keep it *out of the repo*, then add
  repo secrets `ANDROID_KEYSTORE_BASE64` (`base64 -i d0b0-release.jks | pbcopy`),
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. The
  Android job then switches from debug to a signed release APK automatically.
  Pick the keystore *before* anyone installs: changing it later forces a
  reinstall on every phone.
- **Not in CI yet:** signed iOS (needs an Apple Developer account → TestFlight via
  `scripts/release-ios-testflight.sh`), macOS (signing team), Windows (add a
  `windows-latest` job around `scripts/prepare-windows.ps1` + `build-windows.ps1`
  when wanted).
- FCM is deliberately **not** added in CI (`scripts/add-firebase-messaging.sh`);
  d0b0 uses UnifiedPush unless we decide otherwise.
- **Upstream FluffyChat workflows** (`integrate`, `main_deploy`, `release`,
  `matrix_notify`, `stale`) target *their* infrastructure (their GitHub Pages
  nightly, ghcr images, F-Droid/Play secrets, their Matrix room). Remove them —
  or disable them in GitHub (*Actions → workflow → ⋯ → Disable workflow*);
  `main_deploy.yaml` otherwise fires on every push to `main`. When merging
  `upstream/main` later, resolve the resulting modify/delete conflicts by keeping
  them deleted.

## Distribution

- **Android:** hand out the signed APK, or a small personal F-Droid repo. Easy.
- **iOS:** needs an Apple Developer account + Xcode on the Mac — TestFlight (up
  to 10k testers) or sideload (free account = 7-day re-sign). Building is fine on
  the Mac; only distribution needs the account. Unchanged by the framework.
- **Desktop/web:** optional; both build from this repo.

## GitHub setup (✅ done)

`origin` → `git@github.com:SiLiCaP/d0b0-chat.git` (SSH) and `main` is pushed.
`upstream` → FluffyChat stays for pulling updates
(`git fetch upstream && git merge upstream/main`). `gh` is still not installed
(`brew install gh` if you want PRs/releases from the terminal).

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
