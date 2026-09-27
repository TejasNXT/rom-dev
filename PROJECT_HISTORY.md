# PROJECT_HISTORY.md — Realme Pad Nothing OS ROM: The Complete Story

Everything that happened in this project, in order, from the first message
to the current state. This is the "explain it to someone who wasn't there"
file. For just the technical fixes, see BUILD_LOG.md. For the ready-to-run
script, see build.sh / build_and_compile.sh.

---

## 0. The Goal

Turn a Realme Pad (RMP2102) tablet — stock Android 11, feeling slow and
outdated — into a custom ROM that:
1. Runs a modern Android version (ended up targeting Android 14)
2. Looks and feels like a **Nothing Phone** (black/white/red theme, sharp
   corners, dot-matrix aesthetic, Nothing Launcher)
3. Is **faster and smoother** than stock, especially given the tablet's
   4GB RAM

Device specifics: model RMP2102, codename **RMP6768**, board oppo8786,
MediaTek Helio G80/G85 (mt6768), 4GB RAM, 64GB storage, arm64-v8a.

---

## 1. Early exploration — "build a ROM from scratch"

The project started as a broad question: how do you build a custom
Android ROM entirely from scratch (launcher, system apps, frameworks,
everything)? Got a full breakdown of AOSP vs LineageOS vs crDroid as
possible bases, the concept of device tree / kernel / vendor blobs, and a
component-by-component list of what a "Nothing OS" clone would need:
- **Must build from scratch:** launcher, SystemUI, quick settings,
  icon pack, fonts (Ndot/NType style), boot animation, wallpaper app
- **Reskin (keep backend, replace UI):** dialer, messages, camera,
  file manager, clock, calculator, gallery
- **Use directly, no changes:** Android framework, kernel, telephony/
  WiFi/BT stack, media codecs, package manager

Realistic timeline given for a from-scratch build: weeks to months for
device tree/kernel porting alone, 6–12 months to a stable daily driver.
This framed the eventual decision to **not** hand-build every app, and
instead use an existing ROM base + theme injection + reuse an existing
launcher APK — dramatically cutting scope while still hitting the
Nothing OS look.

## 2. Deciding on hardware/software setup

- **Build machine:** Ubuntu installed directly on the internal 476.9GB
  NVMe SSD (an earlier attempt to install Ubuntu on a USB pendrive was
  abandoned due to EFI/legacy BIOS partitioning issues).
- **Partition layout that was actually used:**
  - 260MB EFI boot
  - 174.7GB Windows (untouched)
  - 7.5GB swap partition (leftover from initial install, later
    supplemented)
  - 23.3GB root `/` (too small for build artifacts — learned this the
    hard way)
  - 271.2GB `/home` (where all real work happens)
- **Swap:** first attempt tried to `fallocate` a 16GB swapfile on `/`
  and failed ("No space left on device") because root was nearly full.
  Fixed by moving the swapfile to `/home` instead.
- A 500GB external SSD and a 64GB pendrive were both floated as overflow
  storage options later in the project when `/home` started filling up,
  but the pendrive/SSD detour was never actually completed — the real
  fix that got used was clearing `ccache` and `out/soong/.intermediates`.

## 3. The three-attempt pivot to find a working ROM base

This is the part of the project that consumed the most time and
troubleshooting. Three full attempts were made, in this order:

### Attempt 1 — Pure AOSP
Synced ~80GB of android-14.0.0_r1. Abandoned because the only available
device tree for this tablet was written expecting LineageOS-specific
vendor files (`vendor/lineage/...`), which plain AOSP doesn't have.

### Attempt 2 — LineageOS 21
Re-initialized the same source tree as LineageOS 21.0 and re-synced.
Hit a git hook mismatch on `external/conscrypt` (fixed with
`repo sync --force-sync`), then repeated network stalls at 99% sync
progress (fixed by just re-running the same sync command until it
completed — normal for large syncs). After the full sync completed,
hit an "invalid launch combo" error trying `lunch lineage_RMP6768-userdebug`
— never fully diagnosed at the time; this attempt was abandoned before
finding the exact cause (which, in hindsight, was likely the same class
of AndroidProducts.mk / branch-name confusion solved later in Attempt 3).

### Attempt 3 — Evolution X (the one that stuck)
Switched to Evolution X (`udc` branch = Android 14) for built-in GApps
and Pixel-style features. This required:
- Re-cloning device/vendor/kernel trees, discovering along the way that
  **none of the expected branch names existed**:
  - Device + vendor trees: only `lineage-20.0` exists (not `udc`, not
    `lineage-21.0`)
  - Kernel tree: only `arrow-13.1` exists
  - MediaTek sepolicy repo: branch is `lineage-21` (no dot-zero)
- Discovering the device tree only defines `lineage_RMP6768-*` lunch
  targets, so an `evo_RMP6768.mk` had to be hand-created as a copy,
  registered in `AndroidProducts.mk`, and pointed at
  `vendor/lineage/config/common_full_tablet.mk` (Evolution X has no
  `vendor/evolution/config` — a fix that took two tries to get right).

This is the version that ended up being built to ~181,000 of ~230,000
files compiled, and the version encoded into `build.sh`.

## 4. Original blob/kernel extraction attempts that were bypassed

Before settling on the pre-extracted `Realme-Pad-Dev` vendor tree, there
was an attempt to run the device tree's own `extract-files.sh` to pull
proprietary blobs directly off the tablet via ADB. This failed for three
compounding reasons: the script's `extract_utils.sh` helper was missing,
the LineageOS extract-utils tooling being referenced was the wrong
branch, and — the blocking issue — the tablet has **no root and a locked
bootloader**, so `adb shell su` was never going to work anyway. This was
fully bypassed by cloning the community `Realme-Pad-Dev` vendor tree,
which ships the blobs pre-extracted. No blob extraction was needed after
that.

Similarly, the kernel could not be compiled from source in this
environment (`build.config.RMP6768` requires a specific prebuilt clang
toolchain not present in the synced tree). This was solved by extracting
a working kernel + dtb binary from an **existing ArrowOS (Android 13)
ROM** for the same physical device, downloaded from SourceForge, using
`unpack_bootimg.py` on its `boot.img`. Same hardware, so the kernel
binary works regardless of which ROM it originally shipped in — this is
also why it's fine that the kernel git tree is on an `arrow-13.1` branch.

## 5. The Nothing OS theming layer

Kept intentionally lightweight rather than hand-building a launcher:
- **Colors:** an RRO-style overlay at
  `device/realme/RMP6768/overlay/frameworks/base/core/res/res/values/colors.xml`
  forcing `colorPrimary`/`colorAccent`/etc. to a black/white/red palette.
- **Sharp corners:** a matching `dimens.xml` zeroing out corner-radius
  dimens system-wide.
- **Nothing Launcher:** rather than building a launcher from scratch (as
  the original component checklist suggested), the actual Nothing
  Launcher APK was downloaded from APKMirror. It came as an `.apkm`
  bundle, not a plain `.apk` — had to `unzip` it and pull `base.apk` out,
  rename it to `NothingLauncher.apk`, and wire it into the build as a
  prebuilt system app via `android_app_import` in a new
  `vendor/extra/NothingLauncher/Android.bp`, overriding Trebuchet/
  Launcher3/NexusLauncherRelease. A compatibility check confirmed Nothing
  Launcher does have an Android 14 (API 34)-labeled build, though
  community reports suggested the very first `1.0.0` release is the
  safest bet on custom ROMs (some newer versions reportedly break outside
  official Nothing devices).
- **Performance tweaks** (explicitly requested mid-project once the user
  clarified speed mattered as much as looks): Dalvik heap size tuning,
  LMK pressure properties, `speed-profile` dex compiler filter — aimed at
  keeping the 4GB RAM tablet responsive.
- Boot animation theming was discussed as optional (drop a themed
  `bootanimation.zip` into `device/realme/RMP6768/media/` and reference
  it via `PRODUCT_COPY_FILES`) but was never actually completed in this
  session.

## 6. The long tail of build errors (chronological)

Each of these was hit once, diagnosed, and fixed — all now pre-applied by
build.sh / build_and_compile.sh so a fresh attempt shouldn't need to
rediscover them. Full technical detail on each is in BUILD_LOG.md; in
short, in the order encountered:

1. FMRadio → depends on Qualcomm `libfmjni` → disabled
2. `vendor/evolution/config` doesn't exist → reverted to
   `vendor/lineage/config`
3. `device/mediatek/sepolicy_vndr/SEPolicy.mk` missing → cloned that repo
   (branch `lineage-21`)
4. Qualcomm modules scattered everywhere (`vendor/qcom`, `hardware/qcom`,
   `hardware/qcom-caf`, `hardware/google/gchips`,
   `hardware/google/graphics`, `external/tinycompress`) → all disabled
   by renaming their `Android.bp`. (One overcorrection along the way:
   disabling *all* of `hardware/` broke legitimate framework modules —
   had to restore that folder and be more surgical, only targeting the
   Qualcomm-specific subfolders.)
5. `generated_kernel_headers`/`generated_kernel_includes` undefined →
   traced to `vendor/lineage/build/soong/Android.bp` using Qualcomm-only
   make variables (`PATH_OVERRIDE_SOONG`, `KERNEL_MAKE_CMD`) → removed
   the 4 dependent soong blocks with a small Python script
6. A grab-bag of `BUILD_BROKEN_*` Make sanity-check failures → added the
   matching bypass flags to `BoardConfig.mk`
7. `ALLOW_MISSING_DEPENDENCIES` needed as a shell-exported env var at
   build time, not just a Make flag
8. `ADDNL_GRALLOC_10_USAGE_BITS` undeclared in four `Gralloc*.cpp` files
   → defined as `0` directly in each file
9. `BOARD_RECOVERY_BLDRMSG_OFFSET` undeclared in
   `bootloader_message.h` → same pattern, defined directly in the header
   since the BoardConfig flag alone didn't propagate there
10. No prebuilt kernel available → solved via the ArrowOS boot.img
    extraction described in §4
11. `vendor_load_properties()` undefined symbol at link time → the
    device tree's `libinit_rmp6768` defines it, but linking wasn't
    picking it up → commented out the one call site in
    `system/core/init/property_service.cpp`
12. SEPolicy errors: an `rw_dir_file(...)` macro that wouldn't parse in
    `hal_power_default.te` (expanded by hand into `allow` rules) and
    multiple `.te`/genfscon files in the device tree referencing
    MediaTek-specific types never defined in this source tree (`sysfs_mali`,
    `mtk_hal_audio`, etc.) → those device-specific sepolicy files were
    disabled outright, relying on baseline AOSP/LineageOS sepolicy instead
13. Custom WiFi HAL build rule referencing a missing
    `hardware/interfaces/wifi/1.6/default/service.cpp` → disabled; the
    vendor tree's prebuilt WiFi blobs handle WiFi at runtime regardless

Two "meta" errors along the way, unrelated to Android internals:
- `mka: command not found` — happened once after a PC restart because
  `source build/envsetup.sh` hadn't been re-run in the new shell session
- `ninja: unknown target 'bacon'` — Evolution X source doesn't define a
  `bacon` target (that's a LineageOS-ism); the correct target is
  `target-files-package`

## 7. Storage crises

`/home` (266GB) filling to 100% happened **twice** mid-build — Evolution
X source alone is ~150GB, and `out/soong/.intermediates` alone can
balloon past 50GB during compilation, leaving very little headroom.
Both times, the fix was:
```bash
ccache -C
rm -rf ~/aosp/out/soong/.intermediates
rm ~/Downloads/arrr.zip ~/Downloads/launcher.apkm
rm -rf ~/Downloads/launcher_extracted
```
Important nuance learned here: clearing `.intermediates` resets
**compilation progress** back to 0% (ninja has to recompile everything),
but does **not** undo any device tree fixes/config — those are just
files sitting untouched on disk. This is why the second and third build
attempts had to recompile from scratch even though no new source-level
errors were being introduced — pure lost compile time, not lost fixes.

Considered but not used: mounting the 500GB external SSD or the 64GB
pendrive as build overflow storage via `ln -s` tricks. Never actually
executed in this session.

## 8. Where the build actually got to

The furthest confirmed progress: **~181,268 of ~230,000-ish files**
compiling successfully (exact total shifts slightly between runs
depending on which Qualcomm modules are excluded) before storage ran out
and had to be cleared, resetting compile progress. No confirmed fully
successful `target-files-package` build / ROM zip exists yet as of this
writing. Nothing has been flashed to the tablet.

## 9. Decision NOT to keep manually fixing errors one at a time

After many rounds of "run build → paste error → get a fix → run again",
explicitly decided to stop doing this reactively and instead:
1. Write down every fix discovered so far in one place (BUILD_LOG.md)
2. Encode all of them into a single idempotent script (build.sh) that
   applies everything upfront, before any compilation starts
3. Add a second variant (build_and_compile.sh) that also auto-starts the
   build immediately after applying fixes, for a true "just run it"
   experience
4. Package all of this (plus the raw patch files) into a small git repo
   — deliberately **not** including the 150GB source tree — so the whole
   project can be resumed on any machine with `git clone` + one script,
   without re-discovering any of the above from scratch.

## 10. Safety net — restoring stock firmware

If a flash ever goes wrong: stock RMP2102 firmware is available at
https://firmwarefile.com/oppo-realme-pad-rmp2102 (`.ofp` format), flashed
via Realme Flash Tool (Windows only, hold Volume Up + Volume Down while
connecting USB with tablet powered off). This fully restores factory
Android 11. **Backing up tablet data (photos, contacts, WhatsApp) has
not yet been done** — bootloader is still locked, and this must happen
before any unlock/flash step, since both unlocking and flashing wipe
userdata.

## 11. What's still left, end to end

1. Get a from-scratch run of `build_and_compile.sh` past the ~181k
   checkpoint to a fully finished `target-files-package` build
2. Locate the output ROM zip under
   `~/aosp/out/target/product/RMP6768/`
3. **Back up tablet data** (photos, WhatsApp, contacts)
4. Unlock bootloader (`fastboot flashing unlock` — wipes device)
5. Flash `boot.img` / `vendor.img` / `system.img` via fastboot,
   `fastboot -w`, `fastboot reboot`
6. First-boot verification: does Nothing Launcher load correctly, does
   WiFi work (given the custom HAL was disabled in favor of vendor
   blobs), does the camera work, is the Nothing color/corner theming
   visible system-wide
7. If time allows: the boot animation theming that was discussed but
   never implemented
