#!/usr/bin/env bash
set -euo pipefail

profile="${1:-cloudlab}"
repo_dir="$HOME/workspace/uFS"
ae_script="$HOME/artifact_eval.sh"
patch_dir="$(cd "$(dirname "$0")/patches" && pwd)"

ae() {
  # ae init writes ~/.ae_env.sh with CFS_ROOT_DIR, KFS_MOUNT_PATH, and the
  # build binary paths the Python scripts need; .bashrc normally sources it,
  # but this runs non-interactively so it never gets picked up on its own.
  # SSD_NAME/SSD_PICE_ADDR in that file are a one-time snapshot ae init never
  # updates again, so override them with patch 003's fresh per-node values.
  [ -f "$HOME/.ae_env.sh" ] && . "$HOME/.ae_env.sh"
  AE_BRANCH=sosp-21 AE_UFS_FILEBENCH_BRANCH=sosp-21-filebench-config \
    GIT_TERMINAL_PROMPT=0 SSD_NAME="$AE_SSD_NAME" SSD_PICE_ADDR="$AE_SSD_PICE_ADDR" \
    bash "$ae_script" "$@"
}

fetch_ae_script() {
  [ -f "$ae_script" ] && return
  wget -O "$ae_script" https://raw.githubusercontent.com/WiscADSL/uFS/sosp-21/cfs_bench/exprs/artifact_eval/artifact_eval.sh
}

mount_workspace() {
  # The artifact mounts the workspace itself when using the cloudlab profile.
  [ "$profile" = cloudlab ] && return
  [ -d "$HOME/workspace" ] && return
  sudo mkfs -t ext4 "$AE_WORKSPACE_PART"
  sudo mkdir -p "$HOME/workspace"
  sudo mount "$AE_WORKSPACE_PART" "$HOME/workspace"
  sudo chown "$USER" "$HOME/workspace"
  echo "$AE_WORKSPACE_PART $HOME/workspace ext4 defaults 0 0" | sudo tee -a /etc/fstab
}

clone_and_checkout() {
  [ -d "$repo_dir" ] && return
  # These markers make init clone the source without installing dependencies.
  # Remove them so the next init installs the patched dependencies.
  touch "$HOME/.ae_install_done" "$HOME/.ae_config_done"
  ae init "$profile"
  rm -f "$HOME/.ae_install_done" "$HOME/.ae_config_done"
}

build() {
  [ -f "$HOME/.ufs_built" ] && return
  bash "$patch_dir/001-fix-dead-json-submodule.sh" "$repo_dir"
  bash "$patch_dir/002-pin-fmt-from-folly-manifest.sh" "$repo_dir"
  ae init "$profile"
  bash "$patch_dir/004-bokeh3-figure-args.sh" "$repo_dir"
  touch "$HOME/.ufs_built"
}

reboot_once() {
  [ -f "$HOME/.ufs_rebooted" ] && return
  touch "$HOME/.ufs_rebooted"
  sudo reboot
}

main() {
  fetch_ae_script
  bash "$patch_dir/003-detect-nvme-layout.sh" "$ae_script"
  source "$HOME/.ae_nvme_layout.sh"
  export AE_SSD_NAME AE_SSD_PICE_ADDR

  mount_workspace
  clone_and_checkout
  build
  reboot_once
  ae init-after-reboot "$profile"
}

main "$@"
