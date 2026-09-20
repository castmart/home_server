# Makefile for deploying docker-compose setup to remote host via SSH
#
# Prerequisites:
# - SSH access to remote host (key-based authentication recommended)
# - Remote host has Docker and Docker Compose installed
# - Local SSH, SCP, and rsync commands available
#
# Usage: set SSH_HOST, SSH_USER, SSH_PORT, DEST_DIR as needed
# Example: make copy-to-host SSH_HOST=myserver

# Configuration
SSH_HOST ?= remote-server
SSH_USER ?= $(USER)
SSH_PORT ?= 22
DEST_DIR ?= ~/home_server

# Optional SSH identity. When set, only this key is offered to the server;
# without IdentitiesOnly the agent may exhaust the server's auth attempt limit
# ("Too many authentication failures") before reaching the right key.
SSH_KEY ?=
SSH_OPTS = $(if $(SSH_KEY),-i $(SSH_KEY) -o IdentitiesOnly=yes)

SSH = ssh -p $(SSH_PORT) $(SSH_OPTS)
SCP = scp -P $(SSH_PORT) $(SSH_OPTS)
REMOTE = $(SSH_USER)@$(SSH_HOST)

# Files to copy
COMPOSE_FILES = docker-compose.yaml .env

# Kavita library layout on the remote host (see docker-compose.yaml volumes)
KAVITA_ROOT ?= /mnt/data/kavita
SHELF ?= books
KAVITA_UID ?= 1000
KAVITA_GID ?= 1000

# Destination for a book or series: <root>/<shelf>/<author>[/<series>]
KAVITA_DEST = $(KAVITA_ROOT)/$(SHELF)/$(AUTHOR)$(if $(SERIES),/$(SERIES))

.PHONY: help copy-to-host sync-to-host copy-all remote-status remote-up remote-down remote-logs \
	add-book add-series kavita-ls kavita-perms

help:
	@echo "Deploy docker-compose setup to remote host via SSH"
	@echo ""
	@echo "Targets:"
	@echo "  copy-to-host    Copy docker-compose.yaml and .env to remote host (SCP)"
	@echo "  sync-to-host    Sync project excluding data directories (rsync)"
	@echo "  copy-all        Copy entire project including data (warning: large)"
	@echo "  remote-status   Check remote docker-compose status"
	@echo "  remote-up       Start services remotely"
	@echo "  remote-down     Stop services remotely"
	@echo "  remote-logs     View remote logs"
	@echo ""
	@echo "Kavita library:"
	@echo "  add-book        Upload one file    (BOOK=, AUTHOR=, optional SERIES=)"
	@echo "  add-series      Upload a folder    (SRC=, AUTHOR=, SERIES=)"
	@echo "  kavita-ls       List what is on the remote shelf"
	@echo "  kavita-perms    Hand a path back to $(KAVITA_UID):$(KAVITA_GID) (needs sudo)"
	@echo ""
	@echo "Variables (override with VAR=value):"
	@echo "  SSH_HOST=$(SSH_HOST)"
	@echo "  SSH_USER=$(SSH_USER)"
	@echo "  SSH_PORT=$(SSH_PORT)"
	@echo "  DEST_DIR=$(DEST_DIR)"
	@echo "  SSH_KEY=$(SSH_KEY)"
	@echo "  KAVITA_ROOT=$(KAVITA_ROOT)"
	@echo "  SHELF=$(SHELF)   (books | manga | comics)"
	@echo ""
	@echo "Examples:"
	@echo "  make copy-to-host SSH_HOST=myserver SSH_USER=juan DEST_DIR=/opt/home_server"
	@echo "  make add-book SSH_HOST=myserver AUTHOR='Gary Jennings' BOOK=~/Downloads/Azteca.epub"

copy-to-host: $(COMPOSE_FILES)
	@echo "Copying files to $(REMOTE):$(DEST_DIR)"
	@$(SSH) $(REMOTE) "mkdir -p $(DEST_DIR)"
	@$(SCP) $(COMPOSE_FILES) $(REMOTE):$(DEST_DIR)/
	@echo "Copied: $(COMPOSE_FILES)"
	@echo "Remote directory: $(DEST_DIR)"

# Optional: copy entire directory structure (excluding .git, large data)
sync-to-host:
	@echo "Syncing project to $(REMOTE):$(DEST_DIR)"
	@rsync -avz -e "$(SSH)" \
		--exclude .git \
		--exclude 'immich/pgdata' \
		--exclude 'uploads' \
		--exclude 'pihole/etc-pihole' \
		--exclude 'pihole/etc-dnsmasq.d' \
		./ $(REMOTE):$(DEST_DIR)/
	@echo "Sync complete"

# Copy entire project including data directories (warning: may be large)
copy-all:
	@echo "WARNING: This will copy all data (uploads, database, pihole configs)"
	@echo "Press Ctrl+C to cancel, or wait 5 seconds..."
	@sleep 5
	@echo "Copying entire project to $(REMOTE):$(DEST_DIR)"
	@rsync -avz -e "$(SSH)" \
		--exclude .git \
		./ $(REMOTE):$(DEST_DIR)/
	@echo "Copy complete"

# Check remote docker-compose status
remote-status:
	@$(SSH) $(REMOTE) "cd $(DEST_DIR) && docker compose ps"

# Start services remotely
remote-up:
	@$(SSH) $(REMOTE) "cd $(DEST_DIR) && docker compose up -d"

# Stop services remotely
remote-down:
	@$(SSH) $(REMOTE) "cd $(DEST_DIR) && docker compose down"

# View logs
remote-logs:
	@$(SSH) $(REMOTE) "cd $(DEST_DIR) && docker compose logs -f"

# ── Kavita library ───────────────────────────────────
# Files are added by copying them into the bind-mounted shelves declared in
# docker-compose.yaml; Kavita has no upload endpoint. scp is used rather than
# rsync because macOS still ships rsync 2.6.9, which predates --protect-args
# and mangles remote paths containing spaces. scp on OpenSSH 9+ speaks SFTP,
# so the remote path is taken literally and local quoting is enough.

# Upload a single file: make add-book AUTHOR='Gary Jennings' BOOK=~/Downloads/Azteca.epub
add-book:
	@test -n "$(BOOK)"   || { echo "Error: BOOK=path/to/file.epub is required"; exit 1; }
	@test -n "$(AUTHOR)" || { echo "Error: AUTHOR='Author Name' is required"; exit 1; }
	@test -f "$(BOOK)"   || { echo "Error: no such file: $(BOOK)"; exit 1; }
	@echo "Uploading to $(REMOTE):$(KAVITA_DEST)"
	@$(SSH) $(REMOTE) 'mkdir -p "$(KAVITA_DEST)"'
	@$(SCP) "$(BOOK)" $(REMOTE):"$(KAVITA_DEST)/"
	@echo "Done. Run a library scan in Kavita to pick it up."

# Upload a folder: make add-series AUTHOR='Gary Jennings' SERIES=Azteca SRC=~/Downloads/azteca
add-series:
	@test -n "$(SRC)"    || { echo "Error: SRC=path/to/folder is required"; exit 1; }
	@test -n "$(AUTHOR)" || { echo "Error: AUTHOR='Author Name' is required"; exit 1; }
	@test -n "$(SERIES)" || { echo "Error: SERIES='Series Name' is required"; exit 1; }
	@test -d "$(SRC)"    || { echo "Error: no such directory: $(SRC)"; exit 1; }
	@echo "Uploading to $(REMOTE):$(KAVITA_DEST)"
	@$(SSH) $(REMOTE) 'mkdir -p "$(KAVITA_DEST)"'
	@$(SCP) -r "$(SRC)/." $(REMOTE):"$(KAVITA_DEST)/"
	@echo "Done. Run a library scan in Kavita to pick it up."

# Inspect a shelf: make kavita-ls SHELF=books
kavita-ls:
	@$(SSH) $(REMOTE) 'ls -la "$(KAVITA_ROOT)/$(SHELF)"'

# Only needed when Kavita itself wrote files as root and you cannot edit them
# from your own account. Kavita runs as root in this compose, so it can always
# read what you upload; this is for handing ownership back, not for uploads.
kavita-perms:
	@test -n "$(AUTHOR)" || { echo "Error: AUTHOR='Author Name' is required"; exit 1; }
	@$(SSH) -t $(REMOTE) 'sudo chown -R $(KAVITA_UID):$(KAVITA_GID) "$(KAVITA_DEST)"'

# Show this help
.DEFAULT_GOAL := help
