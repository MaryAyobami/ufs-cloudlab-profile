# uFS reproduction package

This folder contains setup scripts for the SOSP 2021 uFS artifact. uFS is a
filesystem that accesses an NVMe SSD directly through SPDK, the Storage Performance
Development Kit. The scripts adapt the artifact's setup to the dependency and
device-layout problems encountered during this study.

The uFS source, benchmark source, and experiment results are not bundled here.
Setup downloads the artifact's driver and uses that driver to obtain the source
and install dependencies. The complete provisioning and reboot sequence has not
been validated as an unattended run.

## Files

| File | Purpose |
| --- | --- |
| [profile.py](profile.py) | Defines one CloudLab node, its hardware type, its OS image, and the setup service. |
| [setup.sh](setup.sh) | Runs device detection, source checkout, dependency patches, installation, and reboot preparation. |
| [PINNED_COMMIT.ufs](PINNED_COMMIT.ufs) | Records the uFS release and the separate Filebench configuration release. |
| [PINNED_COMMIT.ufs-bench](PINNED_COMMIT.ufs-bench) | Records the benchmark repository revision observed during reproduction. |
| [001-fix-dead-json-submodule.sh](patches/001-fix-dead-json-submodule.sh) | Replaces an unavailable JSON dependency with upstream headers. |
| [002-pin-fmt-from-folly-manifest.sh](patches/002-pin-fmt-from-folly-manifest.sh) | Makes Folly's installer select a compatible fmt release. |
| [003-detect-nvme-layout.sh](patches/003-detect-nvme-layout.sh) | Identifies the OS drive, workspace partition, and separate uFS drive. |
| [004-bokeh3-figure-args.sh](patches/004-bokeh3-figure-args.sh) | Updates plot argument names for Bokeh 3 and later. |

The revision files are records, not lockfiles read by setup. `setup.sh` selects
`sosp-21` for uFS and `sosp-21-filebench-config` for Filebench. It does not enforce
the recorded `uFS-bench` commit; that repository follows the artifact driver's
default branch selection. The recorded benchmark hash is abbreviated.

## How setup works

`profile.py` offers Ubuntu 20.04 and Ubuntu 18.04 images. It selects the
artifact's `cloudlab` setup mode for `c6525-100g` and `other` for every other listed
node type. A type appearing in the selector does not establish that it meets all
of the artifact's hardware requirements.

`setup.sh` accepts that mode as its first argument and defaults to `cloudlab`.
Its sequence is:

1. Download `artifact_eval.sh` from the uFS `sosp-21` release if the file is absent.
2. Run `003-detect-nvme-layout.sh` and load the detected device settings.
3. Prepare `~/workspace`. The artifact handles this in `cloudlab` mode; the wrapper
   formats and mounts the detected partition in `other` mode if the directory is absent.
4. Run the artifact's `init` phase with temporary completion markers so that source
   checkout happens before dependency installation.
5. Apply the JSON and fmt patches, run `init` again to install dependencies, and
   apply the Bokeh patch. Record completion in `~/.ufs_built`.
6. Create `~/.ufs_rebooted` and request a reboot. The intended continuation runs
   `init-after-reboot` to configure simultaneous multithreading (SMT), hugepages,
   and the NVMe driver for uFS.

The setup script can format a partition, modify system configuration, install
packages, and reboot the node. Run it only as part of an approved setup on the
reserved experiment node, inside the named, logged `sess-ufs` tmux session required
by this repository. The wrapper does not create that session itself.

The CloudLab service currently points to `/local/repository/setup.sh`. That
assumes this package is the root of the profile's backing repository. If the
backing repository contains the full study tree, the service path must include
`packages/ufs/`. Select `profile.py` as the profile entry point explicitly.
The service's execution user, home directory, and behavior across reboots still
need validation.

## What each patch does

### Replace the missing JSON submodule

[001-fix-dead-json-submodule.sh](patches/001-fix-dead-json-submodule.sh)
fixes the unavailable `jingliu9/json` repository referenced by `cfs/lib/json`.
Fetching that submodule can prompt for credentials and interrupt dependency setup.

If `cfs/lib/json/single_include/nlohmann/json.hpp` is missing, the script removes
the incomplete JSON checkout and its Git submodule metadata. It then downloads
`nlohmann/json` at `v3.10.4` and removes the downloaded repository's `.git` directory,
leaving the headers in the location expected by uFS. Set `JSON_TAG` to override
that release.

The script initializes the other five submodules by explicit path so Git does not
retry the unavailable JSON repository. An existing header is kept, but its version
is not checked. This substitutes upstream headers; it does not recover the missing
fork's exact contents.

### Pin the fmt version used by Folly

[002-pin-fmt-from-folly-manifest.sh](patches/002-pin-fmt-from-folly-manifest.sh) edits
`cfs/tools/folly_install.sh`. Folly is a C++ support library; fmt provides text
formatting. The original installer clones fmt without selecting a release, which
can pair an old Folly release with an incompatible fmt API.

The patch moves Folly's download and extraction ahead of the fmt clone. The edited
installer reads the fmt release from Folly's dependency manifest and checks out
that release before building fmt. If the manifest yields no version, it falls back
to `6.1.1`. It also disables fmt's tests and documentation in the first matching
`cmake ..` command.

The original installer is saved as `folly_install.sh.orig`. A file containing
`FMT_VER` is treated as already patched. A missing installer or an unrecognized
fmt clone command causes the patch to stop. The patch changes the installer;
it does not build either library itself.

### Configure the NVMe devices

[003-detect-nvme-layout.sh](patches/003-detect-nvme-layout.sh) replaces the
artifact's fixed workspace device path with one derived from the running node.
NVMe drive numbering can differ between reservations, so a fixed name can identify
the wrong disk.

The script finds the parent drive of the root filesystem and expects its fourth
partition to hold the workspace. It chooses the first other NVMe device without
child partitions for uFS and reads that device's PCIe address. It backs up the
artifact driver as `.orig`, rewrites its `DEV_NAME` assignment, and writes
`~/.ae_nvme_layout.sh` with these settings:

- `AE_WORKSPACE_PART`: the workspace partition on the OS drive.
- `AE_SSD_NAME`: the separate NVMe device selected for uFS.
- `AE_SSD_PICE_ADDR`: that device's PCIe address. `PICE` is the spelling expected
  by the artifact.

The script stops if the workspace partition is missing, has a filesystem, or is
mounted. It also stops if it cannot find a separate device or read its address.
It does not format either device itself. Its selection rule checks for child
partitions, not for existing data on an entire unpartitioned drive; inspect the
selected device before allowing setup to use it.

This patch assumes the root filesystem has a directly identifiable parent drive
and that the workspace is partition 4. It is not a general storage-layout detector.
It also **rejects an already formatted workspace**, so calling it unconditionally
prevents the current setup wrapper from resuming normally after its first run.

### Update Bokeh plot arguments

[004-bokeh3-figure-args.sh](patches/004-bokeh3-figure-args.sh) adapts
Python plotting scripts under `cfs_bench/exprs` to Bokeh 3 and later. Bokeh is the
plotting library used by these scripts. Version 3 replaced the figure arguments
`plot_width` and `plot_height` with `width` and `height`.

When the installed Bokeh major version is at least 3, the patch replaces
`plot_width=` and `plot_height=` in matching Python files. It saves each original
file with a `.orig` suffix. It makes no changes for Bokeh 2 or when Bokeh cannot
be imported. The replacement is textual and matches the argument names directly
followed by `=`; it does not parse Python or match every possible spacing style.

## Running individual patches

The JSON, fmt, and Bokeh scripts accept the uFS checkout directory as their first
argument. It defaults to `~/workspace/uFS`. For example, on the reserved node:

```bash
bash patches/001-fix-dead-json-submodule.sh "$HOME/workspace/uFS"
bash patches/002-pin-fmt-from-folly-manifest.sh "$HOME/workspace/uFS"
bash patches/004-bokeh3-figure-args.sh "$HOME/workspace/uFS"
```

Device detection instead accepts the artifact driver path, defaulting to
`~/artifact_eval.sh`. Run it before the initial workspace setup:

```bash
bash patches/003-detect-nvme-layout.sh "$HOME/artifact_eval.sh"
```

These scripts target the artifact's Linux environment. Syntax checks on a local
machine do not validate device discovery, installation, or the reboot sequence.

## Running experiments

After setup and post-reboot initialization have completed successfully, load the
artifact's environment and use its driver inside the logged experiment session.
For the single-threaded microbenchmark:

```bash
source "$HOME/.ae_env.sh"
cd "$HOME/ae_run"
ae cmpl microbench ufsnj
ae run microbench ufs-single
ae run microbench ext4nj
ae plot microbench single
```

The source checkout's `cfs_bench/exprs/artifact_eval/README.md` documents the other
suites and their invocation sequences. The setup wrapper installs dependencies;
experiment compilation still uses `ae cmpl`.

## Remaining limitations

The automatic setup service, execution user, repository path, and reboot
continuation have not been verified together. The unconditional device check
must be addressed before the wrapper can support the repeated execution expected
by the boot service. The `~/.ufs_rebooted` marker records a reboot request, not
proof that a reboot completed. The `~/.ufs_built` marker records that the wrapper
reached the end of its installation phase, not a successful build of every suite.

These patches also leave the recorded uFS runtime failures unresolved: the
LevelDB/YCSB suite encountered a buffer-cache flush assertion, and the Filebench
Varmail sweep encountered a shutdown timing race at high worker counts. Those
failures and the reproduction results are documented separately under `ufs/` in
the study repository.
