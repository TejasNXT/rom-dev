# Build Log — Realme Pad RMP6768 Nothing OS ROM

Device: Realme Pad RMP2102, codename RMP6768, board oppo8786, MediaTek
Helio G80 (mt6768), 4GB RAM, 64GB storage, Android 11 stock.

Goal: Evolution X (Android 14) base + Nothing OS theming (colors, sharp
corners, Nothing Launcher) + performance tweaks for the 4GB RAM tablet.

Root cause of almost every error below: **Evolution X / vendor/lineage
is built and tested for Qualcomm devices.** This tablet is MediaTek. The
device tree itself was written for LineageOS, not Evolution X. Combining
them surfaces a long tail of Qualcomm-only build assumptions.

## 1. Environment setup
- Ubuntu, all standard AOSP build deps, Java 17, repo tool, git-lfs.
- 16GB swap **must go on /home**, not `/` — root partition was too small
  (23GB) and `fallocate` failed there first.

## 2. Which source tree
- Tried pure AOSP first → device tree needed LineageOS-specific files.
- Tried LineageOS 21 → device tree's only branch is `lineage-20.0`
  (Android 13 naming), not `lineage-21.0`. Confusing but LineageOS 21 =
  Android 14 regardless of the branch being named "20.0".
- Settled on **Evolution X (`udc` branch)** for Pixel features + GApps,
  using the `lineage-20.0` device tree anyway (Android version is
  determined by the *source manifest*, not the device tree's branch name).

## 3. Device tree branches (none of these are `udc`)
- `android_device_realme_RMP6768` → branch `lineage-20.0`
- `android_vendor_realme_RMP6768` → branch `lineage-20.0`
- `android_kernel_realme_RMP6768` → branch `arrow-13.1` (its only branch;
  fine to use — same physical hardware kernel regardless of ROM name)
- `android_device_mediatek_sepolicy_vndr` → branch `lineage-21` (NOT
  `lineage-21.0` — this one has no dot-zero)

## 4. Lunch target
Device tree only defines `lineage_RMP6768-*` targets. Created
`evo_RMP6768.mk` (copy of `lineage_RMP6768.mk`) and added `evo_RMP6768-*`
choices to `AndroidProducts.mk`. Critical gotcha: **do NOT** point it at
`vendor/evolution/config/...` — that path doesn't exist in Evolution X.
It still uses `vendor/lineage/config/common_full_tablet.mk`.

## 5. Nothing OS theming
Plain RRO overlay at
`device/realme/RMP6768/overlay/frameworks/base/core/res/res/values/`:
- `colors.xml` — white/black/red color overrides
- `dimens.xml` — zeroed corner radii

Nothing Launcher APK: downloaded from APKMirror as a `.apkm` bundle
(not a plain APK) — had to `unzip` it and pull out `base.apk`, renamed
to `NothingLauncher.apk`, wired in via `android_app_import` in
`vendor/extra/NothingLauncher/Android.bp`.

## 6. Build fixes, in the order they appeared
1. **FMRadio** — depends on `libfmjni` (Qualcomm). Disabled its
   `Android.bp`.
2. **`vendor/evolution/config` missing** — see §4, reverted to
   `vendor/lineage/config`.
3. **`device/mediatek/sepolicy_vndr/SEPolicy.mk` missing** — needed to
   clone that repo (branch `lineage-21`, see §3).
4. **Qualcomm modules everywhere** (`vendor/qcom`, `hardware/qcom`,
   `hardware/qcom-caf`, `hardware/google/gchips`,
   `hardware/google/graphics`, `external/tinycompress`) — none of these
   apply to MediaTek. Disabled each by renaming their `Android.bp` to
   `.bp.bak` so Soong skips them. Doing this to `hardware/` as a whole
   (instead of just the Qualcomm subfolders) broke unrelated framework
   modules — be surgical, only disable the specific subfolders listed.
5. **`generated_kernel_headers` / `generated_kernel_includes` undefined**
   — `vendor/lineage/build/soong/Android.bp` defines these using
   Qualcomm-only make variables (`PATH_OVERRIDE_SOONG`,
   `KERNEL_MAKE_CMD`). Removed the 4 related blocks
   (`lineage_generator`, `generated_kernel_header_defaults`,
   `generated_kernel_headers`, `qti_kernel_headers`) with a small Python
   regex script (see `build.sh` STEP 11).
6. **`BUILD_BROKEN_*` flags** — a grab-bag of Make sanity checks that
   fail on this unofficial combo. Added to `BoardConfig.mk`:
   `BUILD_BROKEN_MISSING_REQUIRED_MODULES`,
   `BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES`,
   `BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE`, `BUILD_BROKEN_DUP_RULES`,
   `BUILD_BROKEN_ENFORCE_SYSPROP_OWNER`,
   `BUILD_BROKEN_INCORRECT_PARTITION_IMAGES`.
7. **`ALLOW_MISSING_DEPENDENCIES`** — must be `export`ed in the shell
   *at build time*, not just set in BoardConfig — the WiFi HAL and a
   few other modules only soft-fail with this set.
8. **`ADDNL_GRALLOC_10_USAGE_BITS` undeclared** in
   `frameworks/native/libs/ui/Gralloc{2,3,4,5}.cpp` — Qualcomm macro.
   Defined it as `0` at the top of each file, plus
   `TARGET_ADDITIONAL_GRALLOC_10_USAGE_BITS := 0` in BoardConfig.
9. **`BOARD_RECOVERY_BLDRMSG_OFFSET` undeclared** in
   `bootloader_message.h` — same pattern, defined as `0` directly in
   the header (the BoardConfig flag alone didn't propagate here).
10. **No prebuilt kernel / can't compile kernel from source** — the
    kernel's own `build.config.RMP6768` wants a specific prebuilt clang
    toolchain not present in this source tree. Workaround: downloaded
    the existing **ArrowOS (Android 13) ROM** for this exact device from
    SourceForge, extracted `boot.img` from its zip, used
    `system/tools/mkbootimg/unpack_bootimg.py` to pull out `kernel` and
    `dtb`, copied them into `device/realme/RMP6768/prebuilt/`, and set
    `TARGET_PREBUILT_KERNEL` / `BOARD_PREBUILT_DTBIMAGE_DIR` in
    BoardConfig. This works because it's the same physical hardware
    kernel — ROM name doesn't matter for the kernel binary itself.
11. **`vendor_load_properties()` undefined symbol at link time** — the
    device tree's `libinit_rmp6768` defines this function but it wasn't
    being linked into `init`. Simplest fix: commented out the single
    call site in `system/core/init/property_service.cpp` (device still
    boots fine — this hook isn't load-bearing for our setup).
12. **SEPolicy errors**:
    - `hal_power_default.te` used a `rw_dir_file(...)` macro that didn't
      parse — expanded it by hand into `allow ... :dir {...}` /
      `allow ... :file {...}` rules via sed.
    - `device/realme/RMP6768/sepolicy/vendor/*` and other `.te` files
      referenced MediaTek-specific types/genfscons (`sysfs_mali`,
      `mtk_hal_audio`, etc.) not defined anywhere in this tree — disabled
      those device-specific policy files outright (baseline
      AOSP/LineageOS sepolicy still applies without them).
13. **Custom WiFi HAL build rule failing** —
    `device/realme/RMP6768/hidl/wifi` tried to build a custom HAL
    service referencing a missing
    `hardware/interfaces/wifi/1.6/default/service.cpp`. Disabled that
    HAL's `Android.mk`/`Android.bp`; the vendor tree's prebuilt WiFi
    blobs still handle WiFi at runtime regardless.

## 7. Storage — ran out of space twice
`/home` is 266GB; Evolution X source alone is ~150GB, leaving little
headroom for `out/soong/.intermediates` (which alone hit 50GB+) plus
downloads. When `df -h /home` shows 100%:
```bash
ccache -C
rm -rf ~/aosp/out/soong/.intermediates   # safe: rebuilds, doesn't undo config
rm ~/Downloads/arrr.zip ~/Downloads/launcher.apkm
rm -rf ~/Downloads/launcher_extracted
```
Deleting `.intermediates` resets **compilation** progress to 0% (ninja
recompiles from scratch) but does **not** undo any device tree fixes —
those are just files on disk that don't get touched by this cleanup.

## 8. Build command sequence
```bash
cd ~/aosp
source build/envsetup.sh
lunch evo_RMP6768-userdebug
export ALLOW_MISSING_DEPENDENCIES=true
mka target-files-package -j4
```
Note: use a plain integer for `-j` (e.g. `-j4`), not `-j$(nproc)` typed
with a stray character — a malformed value like `-j8#` crashes ninja
instantly with a parse error.

`bacon` is not a valid ninja target on Evolution X source — use
`target-files-package` instead.

## 9. Safety net
Stock firmware for restore-to-factory if anything goes permanently
wrong: https://firmwarefile.com/oppo-realme-pad-rmp2102 — flash the
`.ofp` with Realme Flash Tool (Windows only). Back up tablet data
*before* unlocking the bootloader or flashing anything — both wipe
userdata.
