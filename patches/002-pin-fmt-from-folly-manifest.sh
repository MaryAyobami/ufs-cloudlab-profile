#!/usr/bin/env bash
set -euo pipefail

repo_dir="${1:-$HOME/workspace/uFS}"
install_script="$repo_dir/cfs/tools/folly_install.sh"

fail() {
  echo "$*" >&2
  exit 1
}

read_folly_version() {
  folly_url=$(grep -oE 'https://github.com/facebook/folly/archive/[^ ]+\.tar\.gz' "$install_script" | head -n1)
  folly_dir="folly-$(basename "$folly_url" .tar.gz | sed 's/^v//')"
  test -n "$folly_url" || fail "could not find folly tarball URL in $install_script"
}

patch_install_script() {
  # Folly lists its compatible fmt release inside the downloaded source archive.
  cp -n "$install_script" "$install_script.orig"
  awk -v folly_url="$folly_url" -v folly_dir="$folly_dir" -v folly_tgz="$(basename "$folly_url")" '
$0 == "wget " folly_url { next }
/^tar -zxvf/            { next }
/^git clone https:\/\/github.com\/fmtlib\/fmt.git/ {
  print "wget " folly_url
  print "tar -zxvf " folly_tgz
  print "FMT_VER=$(sed -n '\''s|^url = .*/fmt/archive/\\(.*\\)\\.tar\\.gz|\\1|p'\'' \\"
  print "    " folly_dir "/build/fbcode_builder/manifests/fmt)"
  print "if [ -z \"$FMT_VER\" ]; then FMT_VER=6.1.1; fi"
  print $0
  print "git checkout \"$FMT_VER\""
  next
}
/^cmake \.\.$/ && !done_defines {
  print "cmake .. -DFMT_TEST=OFF -DFMT_DOC=OFF"
  done_defines = 1
  next
}
{ print }
' "$install_script.orig" > "$install_script"

  chmod +x "$install_script"
}

main() {
  test -f "$install_script" || fail "not found: $install_script"
  grep -q 'FMT_VER' "$install_script" && return 0
  grep -q '^git clone https://github.com/fmtlib/fmt.git' "$install_script" || \
    fail "pattern not found in $install_script"

  read_folly_version
  patch_install_script
}

main "$@"
