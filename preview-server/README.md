# PR preview server

Every same-repo pull request gets a live Android emulator and a web build, both
served from the TrueNAS box at home under `https://test-d0b0.apapss.id.lv/pr-<N>/`.
The landing page there links to both and lists the test accounts.

```
GitHub ──(runner polls, outbound only)──> d0b0-runner ──docker──> android-pr-<N> (emulator, noVNC :6080)
                                                     └─files──> sites/pr-<N>/web

Cloudflare Access (/pr-*) ─> tunnel ─> d0b0-caddy ─┬─ /_matrix, /_synapse/client ─> Synapse (public)
                                                    ├─ /pr-<N>/, /pr-<N>/web/    ─> landing page, web build
                                                    └─ /pr-<N>/...               ─> android-pr-<N>:6080
```

- CI (`d0b0-ci.yaml`, GitHub-hosted) builds the APK and web artifacts. The server never builds anything.
- `.github/workflows/pr_preview.yaml` runs on the self-hosted runner when CI finishes for a
  PR: it downloads both artifacts, starts or reuses `android-pr-<N>`, installs the APK,
  publishes the web build and comments on the PR. Closing the PR removes everything.
  With more than `MAX_PREVIEWS` previews, the oldest is evicted.
- The test homeserver is the `matrix-server` app on the same box (`test-d0b0.apapss.id.lv`,
  registration closed, federation off). It is not production; `d0b0.lv` is never touched.

## Server layout

All on the `nas/apps/d0b0-preview` dataset:

| Path | What |
|---|---|
| `config/Caddyfile`, `config/landing/` | Copies of the files in this folder |
| `sites/pr-<N>/web/` | Web builds, written by the runner |
| `secrets/testers.json` | Test accounts shown on the landing page (root-only folder, never in git) |
| `secrets/runner.env` | `RUNNER_TOKEN=...` for the first registration |
| `runner/` | Runner registration; keep it, or the runner needs a new token |

`testers.json` looks like:

```json
{ "homeserver": "test-d0b0.apapss.id.lv",
  "accounts": [ { "user": "tester1", "password": "..." }, { "user": "tester2", "password": "..." } ] }
```

## Setup

Already done on the current box: datasets, `testers.json`, test accounts, emulator image pulled.

1. **Copy the config** from this folder to `/mnt/nas/apps/d0b0-preview/config/`
   (`Caddyfile` and `landing/`), and create `sites/` and `runner/` next to it.
2. **Runner token.** Repo → Settings → Actions → Runners → New self-hosted runner, copy
   the token from the `config.sh` line, and write `RUNNER_TOKEN=<token>` into
   `secrets/runner.env`. It expires after an hour, so install the app right after.
3. **Install the app.** TrueNAS → Apps → Discover → Custom App → Install via YAML, name
   `d0b0-preview`, paste `compose.yaml`. Check that `truenas-preview` shows up as Idle under
   Runners with labels `self-hosted, linux, x64, kvm`.
4. **Tunnel.** Cloudflare Zero Trust → Networks → Tunnels → the existing tunnel → Public
   hostname `test-d0b0.apapss.id.lv`: change the service to `http://d0b0-caddy:80`.
   Synapse stays reachable because Caddy forwards `/_matrix` and `/_synapse/client`.
5. **Access.** Zero Trust → Access → Applications → Add → Self-hosted:
   domain `test-d0b0.apapss.id.lv`, path `pr-*`; login method GitHub (or one-time PIN);
   policy *Allow* with the testers' emails. Do this before sharing any link: anyone who
   reaches an emulator controls it.
6. **Repo settings.** Variables: `PREVIEW_BASE_URL=https://test-d0b0.apapss.id.lv`,
   `MAX_PREVIEWS=2`. Under Actions → General, keep "Require approval for all outside
   collaborators" for fork PR workflows.

## Sizing

Each emulator needs about 6.5 GB of RAM and two CPU cores; it boots in about 90 s. The
current box (i3-8100, 4 cores, 23 GB, also running Immich and Synapse) fits
`MAX_PREVIEWS=2`. Web previews are static files and cost nothing.

## Operating it

```sh
docker ps --filter label=d0b0.preview.pr           # running previews
docker rm -f android-pr-<N>                        # kill one by hand
docker logs -f d0b0-runner                         # runner log
docker restart d0b0-runner                         # restart the runner (or restart the app in TrueNAS)
```

If `runner/` is lost, the runner cannot re-register on its own: remove the old runner in
the repo settings, put a fresh token in `secrets/runner.env` and restart the app.

To add a tester account on the homeserver, use Synapse's shared-secret registration
(`register_new_matrix_user` in the `ix-matrix-server-synapse-1` container) and add it to
`testers.json`.

## Security rules

- Never check out or run PR code on the server. Don't switch the triggers to
  `pull_request` and don't add `actions/checkout` of the PR head.
- Fork PRs get no preview; their APK would run on the home network.
- The runner holds the Docker socket, which is root on the box. It is scoped to this repo only.
- No secrets in the repo: runner tokens and test accounts live in `secrets/` on the server.
