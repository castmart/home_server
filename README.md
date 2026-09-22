# In‑House Photo Backup Server with Immich

A minimal Docker Compose configuration to run your own private photo and video backup server using [Immich](https://immich.app), plus Pi‑hole for network‑wide ad‑blocking and Cloudflare Tunnel for secure remote access.

## Overview

This setup provides:
- **Immich** – Self‑hosted photo/video backup (Google Photos alternative)
- **Pi‑hole** – Network‑level DNS‑based ad/tracker blocking
- **Cloudflare Tunnel** – Secure remote access without port‑forwarding
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
   cp .env.example .env  # if available, or create from scratch
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
   - Cloudflare Tunnel: configure at [dashboard.cloudflare.com](https://dash.cloudflare.com/)

## Services

| Service | Port | Description |
|---------|------|-------------|
| `immich‑server` | 2283 | Immich API and web interface |
| `immich‑microservices` | – | Background jobs (thumbnails, metadata, etc.) |
| `immich‑postgres` | – | Database (PostgreSQL + vector extension) |
| `immich‑redis` | – | Job queue |
| `pihole` | 53 (TCP/UDP), 8080 | DNS server and admin UI |
| `cloudflared` | – | Cloudflare Tunnel agent |
| `kavita` | 5000 | Reading server for books, manga and comics |

**Note**: The ML container (`immich‑machine‑learning`) is intentionally omitted; facial recognition and object detection will be unavailable unless added.

## Configuration

Key environment variables (set in `.env`):

| Variable | Purpose | Example |
|----------|---------|---------|
| `UPLOAD_LOCATION` | Where Immich stores uploaded media | `./uploads` |
| `IMMICH_VERSION` | Immich container tag | `release` |
| `TZ` | Timezone | `America/New_York` |
| `PIHOLE_PASSWORD` | Pi‑hole web interface password | `your‑password` |
| `TUNNEL_TOKEN` | Cloudflare Tunnel token | `(from Cloudflare dashboard)` |
| `DB_PASSWORD` | PostgreSQL password | `postgres` |

## Data Persistence

All data is stored on the host via bind mounts:

- `./uploads` – Immich photos/videos
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

- **Immich microservices**: This setup splits `immich‑server` and `immich‑microservices` for background job processing, unlike the official single‑container default.
- **Cloudflare Tunnel**: The tunnel container currently uses Docker Compose’s default network; if your Cloudflare dashboard points to `localhost:2283`, add `network_mode: host` to the service.
- **Pi‑hole**: Admin UI runs on port 8080 to avoid conflicts with other web services.
- **Database**: Uses `tensorchord/pgvecto‑rs` for vector similarity search (required by Immich).

## License

Project configuration: MIT  
Immich: [AGPL‑3.0](https://github.com/immich‑app/immich/blob/main/LICENSE)  
Pi‑hole: [EUPL‑1.2](https://github.com/pi‑hole/pi‑hole/blob/master/LICENSE)  
Cloudflare Tunnel: proprietary