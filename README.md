# In‑House Photo Backup Server with Immich

A minimal Docker Compose configuration to run your own private photo and video backup server using [Immich](https://immich.app), plus Kavita for books and comics, Syncthing for file sync, Pi‑hole for network‑wide ad‑blocking, and a choice of Tailscale or a Cloudflare Tunnel for secure remote access.

## Overview

This setup provides:
- **Immich** – Self‑hosted photo/video backup (Google Photos alternative)
- **Pi‑hole** – Network‑level DNS‑based ad/tracker blocking
- **Remote access** – Tailscale on the host (default), or a Cloudflare Tunnel container (see [REMOTE_ACCESS_SETUP.md](REMOTE_ACCESS_SETUP.md))
- **Kavita** – Self‑hosted reading server for books, manga and comics
- **Syncthing** – Continuous peer‑to‑peer file sync (used here for an Obsidian vault)

All services run in Docker containers, with data stored on the host filesystem.

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd home_server
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your settings (see Configuration below)
   ```

3. **Prepare Syncthing** — required before the first start

   Syncthing needs two variables in `.env` and two host directories owned by
   UID 1000. Without them `docker compose` refuses to run at all, for every
   service. Follow [SYNCTHING_FIRST_RUN.md](SYNCTHING_FIRST_RUN.md) now.

4. **Start services**
   ```bash
   docker compose up -d
   ```

5. **Access services**
   - Immich: http://localhost:2283
   - Pi‑hole admin: http://localhost:8080 (password in `.env`)
   - Kavita: http://localhost:5000
   - Syncthing: http://localhost:8384
   - Remote access: see [REMOTE_ACCESS_SETUP.md](REMOTE_ACCESS_SETUP.md)

## Services

| Service | Port | Description |
|---------|------|-------------|
| `immich‑server` | 2283 | Immich API and web interface |
| `immich‑microservices` | – | Background jobs (thumbnails, metadata, etc.) |
| `immich‑postgres` | – | Database (PostgreSQL + vector extension) |
| `immich‑redis` | – | Job queue |
| `pihole` | 53 (TCP/UDP), 8080 | DNS server and admin UI |
| `cloudflared` | – | Cloudflare Tunnel agent — only with `COMPOSE_PROFILES=cloudflare` |
| `kavita` | 5000 | Reading server for books, manga and comics |
| `syncthing` | 8384, 22000, 21027 | File sync daemon and web GUI |
| `syncthing‑init` | – | One‑shot: writes GUI credentials before the daemon starts |

**Note**: The ML container (`immich‑machine‑learning`) is intentionally omitted; facial recognition and object detection will be unavailable unless added.

## Configuration

Key environment variables (set in `.env`):

| Variable | Purpose | Example |
|----------|---------|---------|
| `UPLOAD_LOCATION` | Where Immich stores uploaded media | `./uploads` |
| `IMMICH_VERSION` | Immich container tag | `release` |
| `TZ` | Timezone | `America/New_York` |
| `PIHOLE_PASSWORD` | Pi‑hole web interface password | `your‑password` |
| `COMPOSE_PROFILES` | Remote access mode: empty for Tailscale, `cloudflare` for the tunnel | `(empty)` |
| `TUNNEL_TOKEN` | Cloudflare Tunnel token (V1 only) | `(from Cloudflare dashboard)` |
| `SYNCTHING_GUI_USER` | Syncthing web GUI username (**required**) | `admin` |
| `SYNCTHING_GUI_PASSWORD` | Syncthing web GUI password (**required**) | `your‑password` |
| `OBSIDIAN_PATH` | Host path to the synced vault | `/mnt/data/syncthing/obsidian` |
| `DB_PASSWORD` | PostgreSQL password | `postgres` |

## Remote Access

Reaching the server from outside the house is a choice between two approaches,
both documented in full in [REMOTE_ACCESS_SETUP.md](REMOTE_ACCESS_SETUP.md):

- **V2 — Tailscale** (default). Installed as a system service on the host, not
  as a container. Services are reachable at the host's tailnet address from any
  device signed into your tailnet. Nothing is published to the internet, and
  setup is one package plus a login — no domain, no DNS records, no policies.
- **V1 — Cloudflare Tunnel**. The `cloudflared` container, behind the
  `cloudflare` compose profile. Gives a public URL that anyone can open without
  installing anything, at the cost of a domain, per-hostname routing and access
  policies to configure — and a server exposed to the internet.

Select the mode in `.env`:

```bash
COMPOSE_PROFILES=            # Tailscale
COMPOSE_PROFILES=cloudflare  # Cloudflare Tunnel
```

## Data Persistence

All data is stored on the host via bind mounts:

- `./uploads` – Immich photos/videos
- `./immich/pgdata` – PostgreSQL database
- `./pihole/etc‑pihole` – Pi‑hole configuration
- `./pihole/etc‑dnsmasq.d` – Pi‑hole DNS settings
- `/mnt/data/kavita/{books,manga,comics}` – Kavita library shelves
- `/mnt/data/kavita/saved/config` – Kavita database and settings
- `./syncthing/config` – Syncthing device identity and settings (gitignored — holds the device private key)
- `/mnt/data/syncthing/obsidian` – the synced Obsidian vault

Data survives container removal; backup these directories.

## Deployment to Remote Host

A `Makefile` provides SSH‑based deployment:

```bash
# Copy compose files to remote server
make copy‑to‑host SSH_HOST=your‑server DEST_DIR=/opt/home_server

# Sync project (excluding large data)
make sync‑to‑host SSH_HOST=your‑server

# Manage remote services
make remote‑status SSH_HOST=your‑server
make remote‑up SSH_HOST=your‑server
```

Pass `SSH_KEY=~/.ssh/id_ecdsa` to any target to select an identity; it also sets
`IdentitiesOnly=yes`, so a crowded `~/.ssh` cannot exhaust the server's
authentication attempt limit before the right key is offered.

Run `make help` for all targets and variables.

## Adding Books to Kavita

Kavita has no upload button. Content is added by copying files into the shelves
that `docker-compose.yaml` bind-mounts from the host:

| Shelf | Host path | Mounted as |
|-------|-----------|------------|
| `books` | `/mnt/data/kavita/books` | `/books` |
| `manga` | `/mnt/data/kavita/manga` | `/manga` |
| `comics` | `/mnt/data/kavita/comics` | `/comics` |

### Expected layout

Kavita groups by folder, one level of author and one of series:

```
/mnt/data/kavita/books/Gary Jennings/Azteca/Azteca.epub
/mnt/data/kavita/manga/Berserk/Berserk Vol. 01.cbz
```

Titles and authors come from the file's own metadata (epub `OPF`, ComicInfo.xml),
not from the filename — a wrong title is fixed in the file or in Kavita's
*Edit Series* dialog, not by renaming. Filenames still matter for ordering:
number them `Vol. 01`, `Vol. 02` if you want a reliable reading order.

### Add a single book

```bash
make add-book SSH_HOST=homeserver AUTHOR='Gary Jennings' BOOK=~/Downloads/Azteca.epub
```

Add `SERIES=` when the book belongs to one, and `SHELF=manga` or `SHELF=comics`
to target another shelf. `SSH_KEY=~/.ssh/id_ecdsa` picks a specific identity.

### Add a whole series

Put the files in one local folder, then upload the folder's contents:

```bash
make add-series SSH_HOST=homeserver AUTHOR='Gary Jennings' SERIES=Azteca SRC=~/Downloads/azteca
```

### Then scan

Open Kavita at `http://<host>:5000`, pick the library and run **Scan Library**.
Kavita also scans on its own schedule, so new files appear eventually without it.

### Checking and permissions

```bash
make kavita-ls SSH_HOST=homeserver SHELF=books
```

The Kavita container runs as root in this compose, so it can read anything you
upload regardless of owner — uploads do not need a `chown`. The reverse case is
the real one: files Kavita writes are owned by root and you may not be able to
edit or delete them from your own account. `make kavita-perms` hands a path
back:

```bash
make kavita-perms SSH_HOST=homeserver AUTHOR='Gary Jennings' SERIES=Azteca
```

### Why scp and not rsync

macOS still ships rsync 2.6.9 (2006), which predates `--protect-args`. Without
it, a remote path containing spaces — and author and series folders usually do —
is re-split by the remote shell and the transfer lands in the wrong place or
fails outright. `scp` on OpenSSH 9+ speaks SFTP, where the remote path is taken
literally, so local quoting is all that is needed. For bulk or resumable
transfers, install a current rsync (`brew install rsync`) and use `-s`.

## Syncthing

Continuous two-way sync between the server and your devices. Set up here for an
Obsidian vault, but any folder works the same way.

### ⚠️ Before the first run

**Read [SYNCTHING_FIRST_RUN.md](SYNCTHING_FIRST_RUN.md) and follow it in order.**
It is the ordered procedure for a server with no Syncthing data yet: the
variables, the host directories and their ownership, the identity check, and
pairing the first device safely.

Two of those steps exist because skipping them causes real damage, so they are
worth repeating here:

- **Set `SYNCTHING_GUI_USER` and `SYNCTHING_GUI_PASSWORD` in `.env` first.**
  Compose interpolates the whole file, so until both are set *every* compose
  command fails — including starting Immich.
- **Make the host directories and give them to UID 1000 before starting.** The
  container entrypoint only chowns `/var/syncthing`, not the bind-mounted
  subdirectories, so a root-owned directory silently fails to write.

### How the credentials work

`syncthing-init` runs `syncthing generate` to completion first, writing the
device identity and the bcrypt-hashed GUI password, and only then does the
daemon start. The GUI at `http://<host>:8384` asks for those credentials
immediately, so it is never reachable unauthenticated.

`.env` stays the source of truth for the password: every `docker compose up -d`
re-applies it, so a password changed in the web UI is reverted on the next
start. Change it in `.env` instead.

### Pairing another device

The first device is covered by the first-run procedure. For every device after
it:

1. Install Syncthing on the laptop or phone and open its own GUI.
2. On the server, *Actions → Show ID* and copy the device ID.
3. On the client, *Add Remote Device*, paste the ID, and accept the prompt that
   appears back on the server.
4. Share the folder with the new device under the *Sharing* tab.

Both ends must agree before anything moves — the pairing is symmetric, and a
device you have not accepted on the server cannot pull anything. If the new
device starts empty, set its folder to *Receive Only* until the first sync
finishes.

### Obsidian-specific ignores

An Obsidian vault contains files that change on every keystroke or that are
machine-specific, and syncing them produces a steady stream of conflict
copies. Add a `.stignore` in the folder root, via *Folder → Edit → Ignore
Patterns*:

```
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache
.trash
.DS_Store
```

Keep the rest of `.obsidian/` synced if you want plugins and settings to follow
you between machines. Turn on *File Versioning* (Simple, a few versions) on the
folder as well: Syncthing resolves a genuine conflict by renaming one side to
`*.sync-conflict-*`, and versioning is what lets you recover the other.

### Over Tailscale

Syncthing finds peers on the LAN by broadcast on 21027, which does not cross
networks. With Tailscale on both ends, add the server's tailnet address
explicitly on the client as `tcp://<machine>.<tailnet>.ts.net:22000` under the
remote device's *Addresses* field, and sync keeps working from anywhere without
relying on Syncthing's public relays.

## Notes

- **Immich microservices**: This setup splits `immich‑server` and `immich‑microservices` for background job processing, unlike the official single‑container default.
- **Remote access**: Two documented approaches — Tailscale installed on the host (default) and a `cloudflared` container behind the `cloudflare` compose profile. Setup, trade-offs and the steps to retire the tunnel are in [REMOTE_ACCESS_SETUP.md](REMOTE_ACCESS_SETUP.md).
- **Pi‑hole**: Admin UI runs on port 8080 to avoid conflicts with other web services.
- **Database**: Uses `tensorchord/pgvecto‑rs` for vector similarity search (required by Immich).
- **Syncthing**: First-time setup has an order that matters — see [SYNCTHING_FIRST_RUN.md](SYNCTHING_FIRST_RUN.md). The GUI is published on the LAN, and Syncthing has no authentication out of the box. A one‑shot `syncthing‑init` service writes credentials from `.env` before the daemon starts, so there is never a window where the UI is open. Compose refuses to run until `SYNCTHING_GUI_USER` and `SYNCTHING_GUI_PASSWORD` are set — including for the other services.

## License

Project configuration: MIT  
Immich: [AGPL‑3.0](https://github.com/immich‑app/immich/blob/main/LICENSE)  
Pi‑hole: [EUPL‑1.2](https://github.com/pi‑hole/pi‑hole/blob/master/LICENSE)  
Kavita: [GPL‑3.0](https://github.com/Kareadita/Kavita/blob/develop/LICENSE)  
Cloudflare Tunnel: proprietary  
Tailscale client: [BSD‑3‑Clause](https://github.com/tailscale/tailscale/blob/main/LICENSE)  
Syncthing: [MPL‑2.0](https://github.com/syncthing/syncthing/blob/main/LICENSE)