#!/usr/bin/env bash
# Host-level memory tuning. Unlike every other script here, this one changes
# the *host*, not the stack, and the first change needs a reboot to take
# effect. Nothing is applied until you run it; it prints a diff-style summary
# and asks before touching anything unless given --yes.
#
# Usage:
#   ./scripts/maintenance/tune-host-memory.sh          # show what would change
#   ./scripts/maintenance/tune-host-memory.sh --apply  # make the changes (prompts)
#   ./scripts/maintenance/tune-host-memory.sh --apply --yes
#
# ===========================================================================
# 1. Enable the memory cgroup controller  (REBOOT REQUIRED)
# ===========================================================================
# The Raspberry Pi kernel ships with the memory cgroup controller disabled -
# /proc/cmdline contains `cgroup_disable=memory` and
# /sys/fs/cgroup/cgroup.controllers lists only `cpuset cpu io pids`.
#
# Three consequences, and they are the root cause of two separate problems in
# this stack:
#
#   a) `docker stats` reports 0B of memory for every container, and the Docker
#      API omits memory_stats.usage entirely.
#   b) Beszel's agent therefore refuses every container with
#      "bad memory stats - see https://github.com/henrygd/beszel/issues/144",
#      so NONE of the services appear in Beszel. This is why the dashboard
#      looked empty even after the system registered correctly.
#   c) `deploy.resources.limits.memory` in docker-compose.yml is silently
#      ignored - Docker cannot enforce a limit without the controller. Any
#      memory limit added to the compose file today does nothing at all.
#
# Cost: the controller adds per-page accounting overhead, generally quoted at
# ~1% of RAM plus a small CPU cost. On 8 GB that is worth paying to get
# working limits and working per-service monitoring.
#
# ===========================================================================
# 2. Enlarge zram  (applies on reboot)
# ===========================================================================
# zram is compressed swap held in RAM. Measured on this box, it was holding
# 1.9 GB of swapped pages in 226 MB of actual memory - roughly 8.7x
# compression, because the things that get swapped here are JVM heaps and
# Python interpreters, which compress extremely well.
#
# The default from /usr/lib/systemd/zram-generator.conf is "50% of RAM or
# 4 GiB, whichever is less", which resolved to 2 GB and was 100% full. Raising
# it to 4 GB buys a lot of headroom for very little real memory, and is much
# cheaper than swapping to the SD card.
#
# This is a safety net, not a fix: pages in zram still cost RAM, and a full
# zram means real memory pressure. It buys time, it does not create memory.
#
# ===========================================================================
# 3. Raise vm.swappiness  (applies immediately)
# ===========================================================================
# Default 60 is tuned for spinning disks, where swapping is catastrophic. With
# zstd-compressed zram, moving a cold page to swap is cheap, so being more
# willing to do it is a win. 100 makes the kernel treat page cache eviction
# and swapping as equally attractive.

set -euo pipefail
cd "$(dirname "$0")/../.."

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

APPLY=0; ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

CMDLINE_FILE=/boot/firmware/cmdline.txt
[[ -f "$CMDLINE_FILE" ]] || CMDLINE_FILE=/boot/cmdline.txt
ZRAM_CONF=/etc/systemd/zram-generator.conf
SYSCTL_CONF=/etc/sysctl.d/99-homelab-memory.conf
ZRAM_SIZE_MB="${ZRAM_SIZE_MB:-4096}"
SWAPPINESS="${SWAPPINESS:-100}"

echo -e "${GREEN}=== Current state ===${NC}"
printf 'cgroup controllers : %s\n' "$(cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null || echo '?')"
if grep -qw memory /sys/fs/cgroup/cgroup.controllers 2>/dev/null; then
  echo -e "memory controller  : ${GREEN}enabled${NC}"
  CGROUP_NEEDED=0
else
  echo -e "memory controller  : ${RED}DISABLED${NC}  (Beszel cannot see containers; memory limits are ignored)"
  CGROUP_NEEDED=1
fi
printf 'zram               : %s\n' "$(zramctl --noheadings --output NAME,DISKSIZE,DATA,TOTAL 2>/dev/null | head -1 || echo 'none')"
printf 'vm.swappiness      : %s\n' "$(cat /proc/sys/vm/swappiness)"
echo

# --- what would change ------------------------------------------------------
echo -e "${GREEN}=== Planned changes ===${NC}"
CHANGES=0

if [[ "$CGROUP_NEEDED" == "1" ]]; then
  if grep -q 'cgroup_enable=memory' "$CMDLINE_FILE" 2>/dev/null; then
    echo "  [already staged] $CMDLINE_FILE has cgroup_enable=memory - reboot pending"
  else
    echo "  [1] append 'cgroup_enable=memory cgroup_memory=1' to $CMDLINE_FILE"
    echo "      -> REBOOT REQUIRED. Fixes Beszel per-container stats and makes"
    echo "         docker-compose memory limits actually enforceable."
    CHANGES=1
  fi
else
  echo "  [1] memory cgroup already enabled - nothing to do"
fi

if [[ -f "$ZRAM_CONF" ]] && grep -q "zram-size *= *${ZRAM_SIZE_MB}" "$ZRAM_CONF" 2>/dev/null; then
  echo "  [2] $ZRAM_CONF already set to ${ZRAM_SIZE_MB} MB"
else
  echo "  [2] write $ZRAM_CONF with zram-size = ${ZRAM_SIZE_MB} MB (currently default: min(50% RAM, 4G))"
  echo "      -> applies on reboot (resizing a live, in-use zram device means"
  echo "         swapoff first, which can stall a memory-tight machine)"
  CHANGES=1
fi

if [[ "$(cat /proc/sys/vm/swappiness)" == "$SWAPPINESS" ]]; then
  echo "  [3] vm.swappiness already $SWAPPINESS"
else
  echo "  [3] set vm.swappiness=$SWAPPINESS via $SYSCTL_CONF (applies immediately + persists)"
  CHANGES=1
fi
echo

if [[ "$APPLY" != "1" ]]; then
  echo -e "${YELLOW}Dry run.${NC} Re-run with --apply to make these changes."
  exit 0
fi

if [[ "$CHANGES" == "0" ]]; then
  echo -e "${GREEN}Nothing to change.${NC}"
  exit 0
fi

if [[ "$ASSUME_YES" != "1" ]]; then
  read -r -p "Apply these changes? [y/N] " reply
  [[ "$reply" == "y" || "$reply" == "Y" ]] || { echo "Aborted."; exit 0; }
fi

# --- 1. cgroup ---------------------------------------------------------------
if [[ "$CGROUP_NEEDED" == "1" ]] && ! grep -q 'cgroup_enable=memory' "$CMDLINE_FILE" 2>/dev/null; then
  BACKUP="${CMDLINE_FILE}.bak.$(date -u +%Y%m%d%H%M%S)"
  echo "==> Backing up $CMDLINE_FILE to $BACKUP"
  sudo cp "$CMDLINE_FILE" "$BACKUP"
  # cmdline.txt must remain ONE line - appending a newline makes the Pi ignore
  # everything after it, which is a genuinely confusing way to lose your boot
  # options. Strip any trailing newline, append, keep it single-line.
  echo "==> Appending cgroup_enable=memory cgroup_memory=1"
  sudo sh -c "printf '%s cgroup_enable=memory cgroup_memory=1\n' \"\$(tr -d '\n' < '$CMDLINE_FILE')\" > '$CMDLINE_FILE'"
  echo "    now: $(cat "$CMDLINE_FILE")"
  if [[ "$(wc -l < "$CMDLINE_FILE")" -gt 1 ]]; then
    echo -e "${RED}WARNING: $CMDLINE_FILE has more than one line. Restore $BACKUP before rebooting.${NC}"
  fi
fi

# --- 2. zram ----------------------------------------------------------------
echo "==> Writing $ZRAM_CONF"
sudo tee "$ZRAM_CONF" >/dev/null <<EOF
# Managed by scripts/maintenance/tune-host-memory.sh
#
# Larger than the default min(50% of RAM, 4G) because the workload here
# compresses very well - measured ~8.7x with zstd, i.e. 1.9 GB of swapped
# pages living in 226 MB of real memory. Compressed swap in RAM is far cheaper
# than swapping to the SD card.
[zram0]
zram-size = ${ZRAM_SIZE_MB}
compression-algorithm = zstd
EOF

# --- 3. swappiness ----------------------------------------------------------
echo "==> Writing $SYSCTL_CONF"
sudo tee "$SYSCTL_CONF" >/dev/null <<EOF
# Managed by scripts/maintenance/tune-host-memory.sh
# Swapping to zstd-compressed zram is cheap, so bias towards it rather than
# evicting page cache. The stock 60 assumes swap lives on a slow disk.
vm.swappiness = ${SWAPPINESS}
EOF
sudo sysctl -q -p "$SYSCTL_CONF"
echo "    vm.swappiness now $(cat /proc/sys/vm/swappiness)"

echo ""
echo -e "${GREEN}Done.${NC}"
if grep -q 'cgroup_enable=memory' "$CMDLINE_FILE" 2>/dev/null && [[ "$CGROUP_NEEDED" == "1" ]]; then
  echo -e "${YELLOW}A reboot is required${NC} for the memory cgroup and the new zram size."
  echo "  sudo reboot"
  echo ""
  echo "After rebooting, verify with:"
  echo "  grep -w memory /sys/fs/cgroup/cgroup.controllers   # should print the list incl. memory"
  echo "  docker stats --no-stream                           # should show real MiB, not 0B"
  echo "  docker logs beszel-agent | tail                    # 'bad memory stats' should be gone"
fi
