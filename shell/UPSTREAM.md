# Where this shell comes from

This folder is SuperAwesomeMagicalLinux's desktop shell. It started as an exact copy of
[Caelestia's shell](https://github.com/caelestia-dots/shell) at release **v2.5.0**
(commit `d999d4878ee4cec134168e60d913714566a8cfa6`, 2026-09-18), without its Nix and GitHub CI
files, and is changed from there in this repository's history. It is GPL-3.0, as upstream is
(`LICENSE`); our changes are under the same licence.

To bring in a newer upstream release: diff upstream's old and new tags and apply that diff here
(`git -C <upstream checkout> diff v2.5.0 vX.Y.Z -- . ':!nix' ':!.github' | git apply -3 --directory=shell`),
resolve conflicts with our changes, then update the Quickshell and M3Shapes pins in
`build_files/` from the new tag's `flake.lock`.
