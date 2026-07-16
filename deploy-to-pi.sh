#!/usr/bin/env bash
# =============================================================================
# deploy-to-pi.sh — Build flowcado for linux/arm64 and deploy to Raspberry Pi
# =============================================================================
# Usage:
#   ./deploy-to-pi.sh [PI_HOST] [PI_USER] [PI_PATH]
#
# Defaults:
#   PI_HOST  = raspberrypi.local  (or set PI_HOST env var)
#   PI_USER  = pi                 (or set PI_USER env var)
#   PI_PATH  = ~/flowcado         (or set PI_PATH env var)
#
# Prerequisites (on Mac):
#   - Docker Desktop running with Buildx enabled
#   - SSH access to the Pi (key-based recommended)
# =============================================================================

set -euo pipefail

# Load local configuration overrides if present
if [[ -f .env.local ]]; then
    source .env.local
fi

# --- Config -------------------------------------------------------------------
PI_HOST="${PI_HOST:-raspberrypi.local}"
PI_USER="${PI_USER:-pi}"
PI_PATH="${PI_PATH:-~/Flowcado}"
IMAGE_NAME="flowcado"
IMAGE_TAG="latest"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
ARCHIVE="flowcado-arm64.tar"
BUILDER_NAME="pi-builder"

# Override from positional args if provided
[[ $# -ge 1 ]] && PI_HOST="$1"
[[ $# -ge 2 ]] && PI_USER="$2"
[[ $# -ge 3 ]] && PI_PATH="$3"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║       Flowcado → Raspberry Pi Deployment         ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Target : ${PI_USER}@${PI_HOST}:${PI_PATH}"
echo "  Image  : ${FULL_IMAGE} (linux/arm64)"
echo ""

# --- Step 1: Ensure Buildx builder for arm64 ----------------------------------
echo "▶ [1/5] Setting up Docker Buildx builder for linux/arm64..."
if ! docker buildx inspect "${BUILDER_NAME}" &>/dev/null; then
    docker buildx create --name "${BUILDER_NAME}" --driver docker-container --use
    docker buildx inspect --bootstrap "${BUILDER_NAME}"
    echo "  ✔ Builder '${BUILDER_NAME}' created."
else
    docker buildx use "${BUILDER_NAME}"
    echo "  ✔ Builder '${BUILDER_NAME}' already exists."
fi

# --- Step 2: Build the image for ARM64 and export to tar ----------------------
echo ""
echo "▶ [2/5] Building linux/arm64 image (this may take a few minutes)..."
docker buildx build \
    --platform linux/arm64 \
    --tag "${FULL_IMAGE}" \
    --output "type=docker,dest=${ARCHIVE}" \
    .

echo "  ✔ Image built and saved to ${ARCHIVE} ($(du -sh "${ARCHIVE}" | cut -f1))"

# --- Step 3: Copy the image archive to the Pi ---------------------------------
echo ""
echo "▶ [3/5] Copying image to Pi (${PI_USER}@${PI_HOST})..."
# Ensure the target directory exists on the Pi
ssh "${PI_USER}@${PI_HOST}" "mkdir -p ${PI_PATH}"
scp "${ARCHIVE}" "${PI_USER}@${PI_HOST}:${PI_PATH}/${ARCHIVE}"
echo "  ✔ Image archive transferred."

# --- Step 4: Copy compose files to the Pi (if not already there) --------------
echo ""
echo "▶ [4/5] Syncing docker-compose.yml and Caddyfile to Pi..."
scp docker-compose.yml "${PI_USER}@${PI_HOST}:${PI_PATH}/docker-compose.yml"
# Only copy Caddyfile if it exists locally
if [[ -f Caddyfile ]]; then
    scp Caddyfile "${PI_USER}@${PI_HOST}:${PI_PATH}/Caddyfile"
fi
echo "  ✔ Compose files synced."

# --- Step 5: Load image and restart the stack on the Pi -----------------------
echo ""
echo "▶ [5/5] Loading image and restarting Flowcado on Pi..."
ssh "${PI_USER}@${PI_HOST}" bash <<REMOTE
set -e
cd ${PI_PATH}

# Pre-create the data dir with open permissions so the non-root
# 'node' container user (UID 1000) can write the SQLite database.
# The bind-mount replaces /data inside the container, so the
# chown inside the Dockerfile has no effect on the host directory.
echo "  → Ensuring data/ directory has correct permissions..."
mkdir -p ./data
# Note: ownership of ./data is handled automatically by entrypoint.sh
# inside the container at startup (chown node:node /data), so no
# sudo chown is needed here.


echo "  → Loading Docker image..."
docker load < ${ARCHIVE}

echo "  → Stopping any existing 'flowcado' container (regardless of project)..."
docker stop flowcado 2>/dev/null || true
docker rm   flowcado 2>/dev/null || true

echo "  → Restarting compose stack..."
docker compose down --remove-orphans || true
docker compose up -d

echo "  → Cleaning up archive..."
rm -f ${ARCHIVE}

echo ""
echo "  ✔ Flowcado is running on the Pi!"
docker compose ps
REMOTE

# --- Cleanup local archive ----------------------------------------------------
echo ""
read -p "Remove local image archive '${ARCHIVE}'? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "${ARCHIVE}"
    echo "  ✔ Local archive removed."
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  🎉 Deployment complete!                         ║"
echo "║                                                  ║"
echo "║  App  → http://${PI_HOST}:3001              "
echo "║  Proxy→ http://${PI_HOST} (via Caddy)       "
echo "╚══════════════════════════════════════════════════╝"
echo ""
