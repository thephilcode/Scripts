# ScreenPhantom Script Library

This repository intentionally tracks the scripts that are currently maintained and used. Older, experimental, and discarded variants are kept in the archive folder instead of cluttering the working root.

## Maintained scripts

The active script set is focused on the three main workflows I still rely on:

- brth.bat
  - Current HEVC re-encode workflow.
  - Historical lineage comes from the earlier batch re-encode scripts that were eventually renamed and refined into the current brth family.

- reenc.bat
  - Current single-file re-encode helper.
  - Earlier numbered variants and experimental copies are preserved in the archive, but the active working history stays here.

- msr.bat
  - Current mux/subtitle re-encode workflow.
  - This is the maintained version of the earlier mux-subtitle re-encode family.

- mux_subs.bat
  - Kept as an active helper only if it is still used; otherwise it may be moved to archive later.

## Archive

The archive folder contains legacy and exploratory files that are no longer part of the day-to-day workflow, including:

- broken or abandoned experiments
- Linux or alternate-environment refactors that are not part of the active Windows workflow
- one-off utilities that are kept only for historical reference

This repository does not try to preserve a duplicate history inside both the root and the archive. The archive is a historical bucket, not a second active development tree.

## Repository guidance

- Keep active source scripts in the repo root.
- Keep generated outputs, catalogs, logs, and temporary folders out of version control.
- Use git history as the true source of versioning for the maintained scripts.
- Use the archive for discardable experiments, old numbered variants, and scripts that are no longer actively maintained.

## Current policy

- root: maintained scripts only
- archive: historical and discarded variants
- ignored: generated outputs, temp folders, logs, catalogs, and other disposable files
