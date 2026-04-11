# In‑House Photo Backup Server with Immich

A minimal Docker Compose configuration to run your own private photo and video backup server using [Immich](https://immich.app), plus Pi‑hole for network‑wide ad‑blocking and Cloudflare Tunnel for secure remote access.

## Overview

This setup provides:
- **Immich** – Self‑hosted photo/video backup (Google Photos alternative)
- **Pi‑hole** – Network‑level DNS‑based ad/tracker blocking
- **Cloudflare Tunnel** – Secure remote access without port‑forwarding

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

Run `make help` for all targets and variables.

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