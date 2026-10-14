#!/usr/bin/env bash
set -euo pipefail

repo_dir="${1:-$HOME/workspace/uFS}"

update_plot_args() {
  local file="$1"
  grep -q 'plot_width\|plot_height' "$file" || return 0
  cp -n "$file" "$file.orig"
  sed -i 's/\bplot_width=/width=/g; s/\bplot_height=/height=/g' "$file"
}

main() {
  local major file
  major=$(python3 -c 'import bokeh; print(bokeh.__version__.split(".")[0])' 2>/dev/null || echo 0)
  # Only Bokeh 3 and later require width/height instead of plot_width/plot_height.
  [ "$major" -lt 3 ] && return 0

  while IFS= read -r file; do
    update_plot_args "$file"
  done < <(grep -rl 'plot_width=\|plot_height=' --include='*.py' "$repo_dir/cfs_bench/exprs" 2>/dev/null)
}

main "$@"
