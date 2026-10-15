#!/usr/bin/env bash
set -euo pipefail

script="${1:-$HOME/artifact_eval.sh}"
os_device=""
spdk_device=""
pci_address=""
workspace_partition=""

fail() {
  echo "$*" >&2
  exit 1
}

detect_os_device() {
  local root_source
  root_source=$(findmnt -n -o SOURCE / | sed 's/\[.*\]//')
  os_device=$(lsblk -no PKNAME "$root_source")
  [ -n "$os_device" ] || fail "cannot resolve root's parent device from $root_source"
}

detect_spdk_device() {
  local device controller
  # Drive numbers can change between reservations. Never give uFS the OS drive.
  for device in $(lsblk -dno NAME | grep '^nvme'); do
    [ "$device" = "$os_device" ] && continue
    [ -z "$(lsblk -no NAME "/dev/$device" | tail -n +2)" ] || continue
    spdk_device="$device"
    break
  done
  [ -n "$spdk_device" ] || fail "no unpartitioned NVMe left for SPDK"

  controller=$(basename "$(readlink -f "/sys/block/$spdk_device/device")")
  controller=${controller%%n[0-9]*}
  controller=${controller/-subsys/}
  pci_address=$(cat "/sys/class/nvme/$controller/address" 2>/dev/null || true)
  [ -n "$pci_address" ] || fail "cannot read PCIe address for $spdk_device"
}

check_workspace_partition() {
  # The artifact expects partition 4 of the OS drive to hold its workspace.
  # setup.sh re-runs on every boot, so a prior successful run of this same
  # script already mounts it at $HOME/workspace by the second boot.
  local part_name
  part_name=$(lsblk -lno NAME,TYPE "/dev/$os_device" | awk '$2=="part"{print $1}' | sed -n '4p')
  [ -n "$part_name" ] || fail "no 4th partition found on /dev/$os_device"
  workspace_partition="/dev/$part_name"

  local mountpoint
  mountpoint=$(findmnt -n -o TARGET -S "$workspace_partition" 2>/dev/null || true)
  if [ -n "$mountpoint" ]; then
    [ "$mountpoint" = "$HOME/workspace" ] && return
    fail "refusing: $workspace_partition is mounted at $mountpoint, not $HOME/workspace"
  fi

  [ -z "$(lsblk -no FSTYPE "$workspace_partition")" ] || \
    fail "refusing: $workspace_partition has a filesystem but isn't mounted; inspect before reusing"
}

update_ae_script() {
  [ -f "$script" ] || fail "artifact_eval.sh not found at $script"
  cp -n "$script" "$script.orig"
  sed -i "s#^\tDEV_NAME=/dev/nvme0n1p4#\tDEV_NAME=$workspace_partition#" "$script"
  grep -q "DEV_NAME=$workspace_partition" "$script" || fail "DEV_NAME rewrite failed"
}

write_layout() {
  # PICE is the artifact's variable spelling; changing it would break setup.
  cat > "$HOME/.ae_nvme_layout.sh" <<LAYOUT
export AE_SSD_NAME=$spdk_device
export AE_SSD_PICE_ADDR=$pci_address
export AE_WORKSPACE_PART=$workspace_partition
LAYOUT
}

main() {
  detect_os_device
  detect_spdk_device
  check_workspace_partition
  update_ae_script
  write_layout
  echo "OS drive: $os_device  workspace: $workspace_partition  SPDK target: $spdk_device at $pci_address"
}

main "$@"
