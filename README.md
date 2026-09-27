# Realme Pad RMP2102 — Nothing OS Custom ROM (Evolution X base)

Working notes + rebuild script for a custom Android 14 ROM (Evolution X,
Nothing OS themed) for the Realme Pad RMP2102 (codename RMP6768, MediaTek
Helio G80 / mt6768).

**This repo does NOT contain the ~150GB Android source tree.** It contains
only the small custom files (device tree patches, overlays, the automated
setup script) needed to reproduce the whole environment from scratch.

## How to resume this project on a fresh machine

Two ways to run it — pick one:

**Option A — fixes only, then build yourself (review before compiling):**
```bash
git clone <this-repo-url>
cd rompad-notes
chmod +x build.sh
bash build.sh 2>&1 | tee ~/rom_build.log
```
Ends by printing the exact 5 build commands — you run those yourself
when ready.

**Option B — fixes AND build in one go (just run it):**
```bash
git clone <this-repo-url>
cd rompad-notes
chmod +x build_and_compile.sh
bash build_and_compile.sh 2>&1 | tee ~/rom_build.log
```
Applies all 17 fixes, then automatically runs `lunch` +
`mka target-files-package -j4` — no manual step in between. This is
what got the build to ~181,000 of ~230,000 files compiled last time.
Run it inside `screen` (see BUILD_LOG.md) since it takes hours.

Either way, you still need to manually download two files first — both
scripts tell you exactly what and where (ArrowOS ROM for kernel
extraction, Nothing Launcher APK) and continue on their own if either
is missing (the kernel/launcher steps just print a warning and skip).

## Files in this repo
- `PROJECT_HISTORY.md` — the full story: every decision, pivot, and dead end from the very first message to now
- `build.sh` — fixes only, prints the build commands at the end for you to run
- `build_and_compile.sh` — same 17 fixes, then automatically starts the build
- `BUILD_LOG.md` — narrative log: every error hit, why it happened, what fixed it
- `device-tree-patches/` — the actual diffs/created files applied to the device tree (colors.xml, dimens.xml, BoardConfig.mk additions, etc.), in case you want to apply them by hand instead of running either script
# rom-dev
