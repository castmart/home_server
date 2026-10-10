# Remote Access Setup

Two supported ways to reach this server from outside the house. Both avoid
port-forwarding and neither requires a static IP. Pick one — they are not meant
to run at the same time.

| | **V1 — Cloudflare Tunnel** | **V2 — Tailscale** (current) |
|---|---|---|
| Runs as | `cloudflared` container, in this compose | System service on the host, outside Docker |
| Reachable by | Anyone with the URL | Only devices signed into your tailnet |
| Needs a domain | Yes, on Cloudflare | No |
| Client setup | None — any browser | Tailscale installed and logged in |
| Transport | Through Cloudflare's edge | Direct WireGuard, usually peer-to-peer |
| Upload size cap | 100 MB per request on the free plan | None |
| Media streaming | Against Cloudflare's terms for non-HTML content at volume | Fine |
| Exposed to the internet | Yes — a public hostname | No — tailnet only |
| Good for | Sharing with people who won't install anything | Your own devices |

This setup moved to V2 for two reasons: the server stops being reachable from
the public internet at all, and there is far less to configure and keep
configured. V1 means a domain on Cloudflare, a tunnel, per-hostname routes, DNS
records and Access policies — each one a place to get it wrong, and the result
is still a public URL that has to be defended. V2 is one package on the host
and a login; nothing is published, so there is no attack surface to harden.

## Which one is active

Remote access is selected by the `COMPOSE_PROFILES` variable in `.env`:

```bash
# V2 — Tailscale on the host (default)
COMPOSE_PROFILES=

# V1 — Cloudflare Tunnel
COMPOSE_PROFILES=cloudflare
```

The `cloudflared` service in `docker-compose.yaml` is behind the `cloudflare`
profile, so it only starts when that profile is active. Everything else —
Immich, Pi-hole, Kavita — is identical either way.

Check what is actually running:

```bash
docker compose ps --services
```

---

# V1 — Cloudflare Tunnel

An outbound-only `cloudflared` container connects to Cloudflare's edge, and
Cloudflare routes a public hostname down that connection. Nothing is exposed on
your router.

## Prerequisites

- A domain whose nameservers point at Cloudflare.
- A Cloudflare account with Zero Trust enabled (the free tier is enough).

## Setup

1. **Create the tunnel.** In the Cloudflare dashboard: *Zero Trust → Networks →
   Tunnels → Create a tunnel → Cloudflared*. Name it, then copy the token from
   the install snippet — the long string after `--token`. Do not run the
   suggested install command; this repo runs the container for you.

2. **Store the token.** In `.env`:

   ```bash
   COMPOSE_PROFILES=cloudflare
   TUNNEL_TOKEN=eyJhIjoi...
   ```

   `.env` is gitignored. The token is a credential that grants control of the
   tunnel — treat it like a password.

3. **Map public hostnames.** Still in the tunnel's config, under *Public
   Hostnames*, add one route per service:

   | Hostname | Service |
   |----------|---------|
   | `photos.example.com` | `http://immich-server:2283` |
   | `books.example.com` | `http://kavita:5000` |

   The service address uses the compose service name and its *internal* port,
   because `cloudflared` resolves it on the compose network. If your dashboard
   is configured against `localhost:2283` instead, add `network_mode: host` to
   the `cloudflared` service — the two styles are mutually exclusive.

4. **Start it.**

   ```bash
   docker compose up -d
   ```

   With the profile set in `.env`, `cloudflared` comes up with everything else.
   To start it ad hoc without touching `.env`:

   ```bash
   docker compose --profile cloudflare up -d
   ```

5. **Verify.**

   ```bash
   docker compose logs -f cloudflared
   ```

   Look for `Registered tunnel connection`. The dashboard should show the
   tunnel as *Healthy*.

## Hardening

A tunnel hostname is public the moment it resolves. Immich and Kavita both have
their own logins, but put Cloudflare Access in front anyway: *Zero Trust →
Access → Applications → Add an application → Self-hosted*, then a policy
allowing only your email addresses. Without it, the login pages themselves are
exposed to the internet and to anyone scanning certificate transparency logs.

## Known limits

- **100 MB per request** on the free plan (Pro is the same, Business 200 MB).
  Immich uploads larger than that fail. This is enforced at Cloudflare's edge
  and cannot be raised from your side.
- **Cloudflare's terms** restrict serving large volumes of non-HTML content —
  video in particular — through the CDN. A personal photo library is widely
  read as being on the wrong side of that line.
- Every byte goes through Cloudflare's edge, so throughput depends on their
  network rather than on your upload link.

---

# V2 — Tailscale on the host

Tailscale puts the server and your devices on one private WireGuard network.
Each machine gets a stable `100.x.y.z` address that works from anywhere, with
no public exposure at all.

It is installed **as a system service on the host, not as a container**. A
container would need `NET_ADMIN`, a `/dev/net/tun` mount and its own state
volume, and would only cover services on the compose network — the host-level
service covers the whole machine, including SSH.

## Install on the host

Already done on this server. For a rebuild:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

```bash
sudo tailscale up
```

That prints a URL to authenticate the machine against your tailnet. Then:

```bash
sudo systemctl enable --now tailscaled
```

Two settings worth applying in the admin console at
[login.tailscale.com](https://login.tailscale.com):

- **Disable key expiry** for this machine (*Machines → … → Disable key
  expiry*). Otherwise the server drops off the tailnet every few months and
  needs a physical login to come back.
- **Enable MagicDNS** (*DNS → MagicDNS*), which gives the host a name instead
  of a bare IP.

## Reaching the services

```bash
tailscale status
```

```bash
tailscale ip -4
```

With MagicDNS on, the services are at `<machine>.<tailnet>.ts.net`:

| Service | URL |
|---------|-----|
| Immich | `http://homeserver.tailnet-name.ts.net:2283` |
| Kavita | `http://homeserver.tailnet-name.ts.net:5000` |
| Pi-hole admin | `http://homeserver.tailnet-name.ts.net:8080` |

Install Tailscale on each phone and laptop, sign into the same tailnet, and
those URLs work from any network. In the Immich mobile app, set the server URL
to the tailnet address — not the LAN IP, which only works at home.

## Optional: HTTPS instead of plain HTTP

Tailscale can terminate TLS with a real certificate for the `.ts.net` name,
which stops browsers complaining and lets Immich's service worker install:

```bash
sudo tailscale serve --bg --https=443 localhost:2283
```

Enable *HTTPS Certificates* in the admin console under *DNS* first. Serve one
service per port — a second service needs its own, e.g. `--https=8443`. The
`serve` subcommand's syntax has shifted between Tailscale releases, so check
`tailscale serve --help` on the installed version before relying on the exact
form above.

## Optional: Pi-hole for the whole tailnet

Point the tailnet at Pi-hole so every connected device gets filtering, not just
devices at home: *DNS → Nameservers → Add nameserver*, using the host's
`100.x.y.z` address, then enable *Override local DNS*.

Pi-hole must accept queries arriving on the Tailscale interface, which it
refuses by default as non-local. The variable that controls this was renamed in
Pi-hole v6 (`DNSMASQ_LISTENING` in v5, `FTLCONF_dns_listeningMode` in v6), and
this compose tracks `pihole/pihole:latest` — check which major version you are
actually running before setting it.

## Do not enable Funnel

`tailscale funnel` publishes a service to the open internet, which throws away
the reason for using Tailscale here. If you need to share with someone outside
the tailnet, prefer a Tailscale **share invite** for that one machine, or
Immich's own public album links.

---

# Teardown: retiring the Cloudflare Tunnel

Run this after Tailscale is confirmed working, not before — step 1 is the
safety check that keeps you from cutting remote access with nothing in its
place.

1. **Confirm V2 works from off-network.** From a phone on cellular, with
   Tailscale connected and Wi-Fi off, load Immich at its tailnet address and
   sign in. Update the server URL in the Immich mobile app on every device
   while you still have both paths available.

2. **Switch the profile off.** In `.env`:

   ```bash
   COMPOSE_PROFILES=
   ```

3. **Stop and remove the container.** Turning off the profile does not remove a
   container that is already running — compose leaves it alone rather than
   treating it as an orphan. Remove it explicitly:

   ```bash
   docker compose rm -sf cloudflared
   ```

   Then confirm it is gone:

   ```bash
   docker compose ps --services
   ```

4. **Delete the tunnel in Cloudflare.** *Zero Trust → Networks → Tunnels →
   select the tunnel → Delete*. This invalidates the token, so the credential
   in `.env` becomes useless whether or not you remove it.

5. **Remove the DNS records.** Deleting a tunnel can leave the `CNAME` records
   it created pointing at a tunnel that no longer exists. In *DNS → Records*,
   delete any record whose target ends in `.cfargotunnel.com`. Left in place
   they resolve to nothing and are a dangling-subdomain risk.

6. **Remove the Access applications.** *Zero Trust → Access → Applications* —
   delete the policies created for those hostnames. They do nothing once the
   tunnel is gone, but they keep the hostnames in your configuration.

7. **Clean up `.env`.** Delete the `TUNNEL_TOKEN` line. The token was never
   committed — `.env` has been gitignored since the first commit — so there is
   no history to rewrite.

8. **Drop the image** (optional):

   ```bash
   docker image rm cloudflare/cloudflared:latest
   ```

Nothing needs to change on the router: the tunnel never opened a port, and
Tailscale does not need one either.

## Going the other way

To put V1 back, set `TUNNEL_TOKEN` and `COMPOSE_PROFILES=cloudflare` in `.env`,
then `docker compose up -d`. The service definition stays in the compose file
permanently, so the path back is a token and a variable — nothing to re-add.
