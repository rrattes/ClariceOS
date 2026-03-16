#!/usr/bin/env bash
# ClariceOS build script
# Builds calamares from AUR into a local repo, then runs mkarchiso

set -euo pipefail

WORK_DIR="${1:-/var/tmp/clariceos-work}"
OUT_DIR="${2:-/var/tmp/clariceos-out}"
LOCAL_REPO_DIR="${3:-/var/tmp/clariceos-local-repo}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run as root (sudo $0)" >&2
  exit 1
fi

# Always clean up temp files on exit (success or failure)
TEMP_PROFILE=""
cleanup() {
  [[ -n "${TEMP_PROFILE}" && -d "${TEMP_PROFILE}" ]] && rm -rf "${TEMP_PROFILE}"
  rm -f /etc/sudoers.d/clariceos-build
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# 1. Set up Chaotic-AUR on host
# ---------------------------------------------------------------------------
echo "==> [1/4] Setting up Chaotic-AUR on host..."

if ! pacman-key --list-keys 3056513887B78AEB &>/dev/null; then
  pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
  pacman-key --lsign-key 3056513887B78AEB
  pacman -U --noconfirm \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' \
    || true
fi

if [[ ! -f /etc/pacman.d/chaotic-mirrorlist ]]; then
  if [[ -f "$SCRIPT_DIR/releng/airootfs/etc/pacman.d/chaotic-mirrorlist" ]]; then
    cp "$SCRIPT_DIR/releng/airootfs/etc/pacman.d/chaotic-mirrorlist" \
       /etc/pacman.d/chaotic-mirrorlist
  else
    echo "  WARNING: /etc/pacman.d/chaotic-mirrorlist not found — Chaotic-AUR package should have installed it."
  fi
fi

# ---------------------------------------------------------------------------
# 2. Build calamares from AUR into a local repo
# ---------------------------------------------------------------------------
echo "==> [2/4] Building calamares from AUR into local repo..."
echo "    (this may take several minutes on first run)"

mkdir -p "$LOCAL_REPO_DIR"

# Need a non-root user to run makepkg
BUILD_USER="clariceos-build"
BUILD_DIR="/tmp/clariceos-aur-build"

if ! id "$BUILD_USER" &>/dev/null; then
  useradd -m -G wheel "$BUILD_USER"
fi
echo "$BUILD_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/clariceos-build
chmod 440 /etc/sudoers.d/clariceos-build

# Install build deps available in repos
pacman -S --needed --noconfirm git base-devel

# Clean and set up build dir
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
chown "$BUILD_USER":"$BUILD_USER" "$BUILD_DIR"

# Function to build an AUR package
aur_build() {
  local pkg="$1"
  echo "    -> Building $pkg from AUR..."
  su - "$BUILD_USER" -c "
    set -e
    cd '$BUILD_DIR'
    rm -rf '$pkg'
    git clone --depth=1 https://aur.archlinux.org/${pkg}.git
    cd '$pkg'
    makepkg -s --noconfirm --noprogressbar 2>&1
  "
  find "$BUILD_DIR/$pkg" -maxdepth 1 -name "*.pkg.tar.zst" \
    -exec cp {} "$LOCAL_REPO_DIR/" \;
}

# Build calamares (and any AUR-only deps)
aur_build calamares

# Update local repo database
repo-add "$LOCAL_REPO_DIR/clariceos-local.db.tar.zst" "$LOCAL_REPO_DIR"/*.pkg.tar.zst

echo "    Local repo built at: $LOCAL_REPO_DIR"

# ---------------------------------------------------------------------------
# 3. Create a temp profile with local repo added to pacman.conf
# ---------------------------------------------------------------------------
echo "==> [3/4] Preparing build profile..."

TEMP_PROFILE=$(mktemp -d /tmp/clariceos-profile-XXXXXX)
cp -r "$SCRIPT_DIR/releng/." "$TEMP_PROFILE/"

cat >> "$TEMP_PROFILE/pacman.conf" << EOF

# Local repo with AUR-built packages (calamares, etc.)
[clariceos-local]
SigLevel = Optional TrustAll
Server = file://$LOCAL_REPO_DIR
EOF

# Clean previous work dir
echo "    Cleaning previous work directory..."
rm -rf "$WORK_DIR"
mkdir -p "$OUT_DIR"

# ---------------------------------------------------------------------------
# 4. Run mkarchiso
# ---------------------------------------------------------------------------
echo "==> [4/4] Running mkarchiso..."

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$TEMP_PROFILE"

echo ""
echo "==> Build complete! ISO is in: $OUT_DIR"
ls -lh "$OUT_DIR"/*.iso 2>/dev/null || true
