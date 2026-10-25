# In‑House Photo Backup Server with Immich

A minimal Docker Compose configuration to run your own private photo and video backup server using [Immich](https://immich.app), plus Kavita for books and comics, Pi‑hole for network‑wide ad‑blocking, and a choice of Tailscale or a Cloudflare Tunnel for secure remote access.

## Overview

This setup provides:
- **Immich** – Self‑hosted photo/video backup (Google Photos alternative)
- **Pi‑hole** – Network‑level DNS‑based ad/tracker blocking
- **Remote access** – Tailscale on the host (default), or a Cloudflare Tunnel container (see [REMOTE_ACCESS_SETUP.md](REMOTE_ACCESS_SETUP.md))
- **Kavita** – Self‑hosted reading server for books, manga and comics

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

3. **Start services**
   ```bash
   docker compose up -d
   ```

4. **Access services**
   - Immich: http://localhost:2283
   - Pi‑hole admin: http://localhost:8080 (password in `.env`)
   - Kavita: http://localhost:5000
   - Remote access: see [REMOTE_ACCESS_SETUP.md](REMOTE_ACCESS_SETUP.md)

## Services

| Service | Port | Description |
|---------|------|-------------|
| `immich‑server` | 2283 | Immich API, web interface and background jobs (thumbnails, metadata, etc.) |
| `immich‑postgres` | – | Database (PostgreSQL + VectorChord) |
| `immich‑redis` | – | Job queue (Valkey) |
| `pihole` | 53 (TCP/UDP), 8080 | DNS server and admin UI |
| `cloudflared` | – | Cloudflare Tunnel agent — only with `COMPOSE_PROFILES=cloudflare` |
| `kavita` | 5000 | Reading server for books, manga and comics |

**Note**: The ML container (`immich‑machine‑learning`) is intentionally omitted from
`docker-compose.yaml`; facial recognition and object detection are unavailable until it
is started from [docker-compose-ml-host.yaml](docker-compose-ml-host.yaml), on the same
`IMMICH_VERSION` as the server.

Immich is pinned to one exact release in `.env`. Upgrading it — including the
major-version jump that removed the `immich‑microservices` container — follows the
procedure in [IMMICH_UPGRADE.md](IMMICH_UPGRADE.md).

## Configuration

Key environment variables (set in `.env`):

| Variable | Purpose | Example |
|----------|---------|---------|
| `UPLOAD_LOCATION` | Where Immich stores uploaded media | `./immich/library` |
| `DB_DATA_LOCATION` | Where the Immich PostgreSQL cluster lives | `./immich/pgdata` |
| `IMMICH_VERSION` | Immich release tag, pinned exactly | `v3.3.5` |
| `TZ` | Timezone | `America/New_York` |
| `PIHOLE_PASSWORD` | Pi‑hole web interface password | `your‑password` |
| `COMPOSE_PROFILES` | Remote access mode: empty for Tailscale, `cloudflare` for the tunnel | `(empty)` |
| `TUNNEL_TOKEN` | Cloudflare Tunnel token (V1 only) | `(from Cloudflare dashboard)` |
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

- `./immich/library` – Immich photos/videos (`UPLOAD_LOCATION`)
- `./immich/pgdata` – PostgreSQL database
- `./pihole/etc‑pihole` – Pi‑hole configuration
- `./pihole/etc‑dnsmasq.d` – Pi‑hole DNS settings
- `/mnt/data/kavita/{books,manga,comics}` – Kavita library shelves
- `/mnt/data/kavita/saved/config` – Kavita database and settings

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

## Notes

- **Immich version**: Pinned to an exact release (`IMMICH_VERSION` in `.env`), currently `v3.3.5`. The server container runs the background workers itself; the separate `immich‑microservices` container no longer exists. See [IMMICH_UPGRADE.md](IMMICH_UPGRADE.md).
- **Remote access**: Two documented approaches — Tailscale installed on the host (default) and a `cloudflared` container behind the `cloudflare` compose profile. Setup, trade-offs and the steps to retire the tunnel are in [REMOTE_ACCESS_SETUP.md](REMOTE_ACCESS_SETUP.md).
- **Pi‑hole**: Admin UI runs on port 8080 to avoid conflicts with other web services.
- **Database**: Uses `ghcr.io/immich-app/postgres` (PostgreSQL 14 with VectorChord) for vector similarity search, required by Immich. v3 dropped support for the older pgvecto.rs extension, so `DB_VECTOR_EXTENSION` must stay unset.

## License

Project configuration: MIT  
Immich: [AGPL‑3.0](https://github.com/immich‑app/immich/blob/main/LICENSE)  
Pi‑hole: [EUPL‑1.2](https://github.com/pi‑hole/pi‑hole/blob/master/LICENSE)  
Kavita: [GPL‑3.0](https://github.com/Kareadita/Kavita/blob/develop/LICENSE)  
Cloudflare Tunnel: proprietary  
Tailscale client: [BSD‑3‑Clause](https://github.com/tailscale/tailscale/blob/main/LICENSE)