# uFS reproduction package

Setup scripts and dependency fixes for the SOSP 2021 uFS artifact.

## Files

- [profile.py](profile.py): CloudLab node and OS selection.
- [setup.sh](setup.sh): downloads the artifact driver, prepares storage, applies
  patches, installs dependencies, and requests a reboot.
- [PINNED_COMMIT.ufs](PINNED_COMMIT.ufs): uFS and Filebench release references.
- [PINNED_COMMIT.ufs-bench](PINNED_COMMIT.ufs-bench): recorded benchmark revision.
  Setup does not enforce this commit.

## Patches

| Patch | What it changes |
| --- | --- |
| [001-fix-dead-json-submodule.sh](patches/001-fix-dead-json-submodule.sh) | Replaces the unavailable `jingliu9/json` dependency with `nlohmann/json` headers at `v3.10.4`, then initializes the remaining submodules. |
| [002-pin-fmt-from-folly-manifest.sh](patches/002-pin-fmt-from-folly-manifest.sh) | Edits Folly's installer to use the fmt version listed in its dependency manifest, falling back to `6.1.1`. Disables fmt tests and documentation. |
| [003-detect-nvme-layout.sh](patches/003-detect-nvme-layout.sh) | Uses partition 4 of the OS drive for the workspace and selects a separate, unpartitioned NVMe drive for uFS. Updates the artifact driver and writes `~/.ae_nvme_layout.sh`. |
| [004-bokeh3-figure-args.sh](patches/004-bokeh3-figure-args.sh) | Changes `plot_width` and `plot_height` to `width` and `height` in the plotting scripts when Bokeh 3 or later is installed. |

Patches 001, 002, and 004 accept the uFS checkout path, defaulting to
`~/workspace/uFS`. Patch 003 accepts the artifact driver path, defaulting to
`~/artifact_eval.sh`. Patches 002–004 keep edited originals as `.orig` files.

## Setup

The profile uses `cloudlab` mode for `c6525-100g` and `other` for the remaining
node types. Its setup service expects this package at `/local/repository`.

Run setup inside the reserved node's logged `sess-ufs` tmux session. Setup can
format the workspace partition and reboot the node; inspect the selected drives
and obtain the required OS-change approval first.

```bash
bash setup.sh cloudlab
```

Setup applies patches in order **003 → 001 → 002 → 004**. Device detection must
happen before workspace preparation, and dependency patches before installation.

Patch 003 refuses an already formatted or mounted workspace, so the current
wrapper cannot resume after initial setup without addressing that check.

## Experiments

Use the artifact driver after setup and post-reboot initialization. For the
single-threaded microbenchmark:

```bash
source "$HOME/.ae_env.sh"
cd "$HOME/ae_run"
ae cmpl microbench ufsnj
ae run microbench ufs-single
ae run microbench ext4nj
ae plot microbench single
```

See the source checkout's `cfs_bench/exprs/artifact_eval/README.md` for other suites.
