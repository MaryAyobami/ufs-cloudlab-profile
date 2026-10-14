#!/usr/bin/env bash
set -euo pipefail

repo_dir="${1:-$HOME/workspace/uFS}"
json_tag="${JSON_TAG:-v3.10.4}"

vendor_json() {
  [ -f cfs/lib/json/single_include/nlohmann/json.hpp ] && return

  # The jingliu9/json repository is unavailable; use nlohmann/json headers instead.
  rm -rf cfs/lib/json .git/modules/cfs/lib/json
  git clone --branch "$json_tag" --depth 1 https://github.com/nlohmann/json.git cfs/lib/json
  rm -rf cfs/lib/json/.git
}

main() {
  cd "$repo_dir"
  export GIT_TERMINAL_PROMPT=0
  vendor_json

  # Listing the other submodules prevents Git from fetching jingliu9/json again.
  git submodule update --init \
    cfs/lib/Catch2 cfs/lib/abseil-cpp cfs/lib/cxxopts cfs/lib/pcm cfs/lib/userspace-rcu
  test -f cfs/lib/json/single_include/nlohmann/json.hpp
}

main "$@"
