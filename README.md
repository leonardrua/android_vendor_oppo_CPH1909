# OPPO A5s (CPH1909) vendor blobs — LineageOS 17.1

Proprietary vendor components for the OPPO A5s / CPH1909 (MediaTek MT6765,
Helio P35), extracted from the stock ColorOS 5.2 / Android 8.1 (API 27)
firmware dump and adapted to run under Android 10 / LineageOS 17.1.

This repository is the `vendor/oppo/CPH1909` half of the port. The matching
device tree lives in `android_device_oppo_CPH1909` and is cloned to
`device/oppo/CPH1909`; its `device.mk` pulls this tree in with

```make
$(call inherit-product-if-exists, vendor/oppo/CPH1909/CPH1909-vendor.mk)
```

The two repositories are co-developed: several HALs that stock ships as blobs
are instead **built from source in the device tree** (fingerprint, power,
lights, face), and a number of blobs here have been **patched or dropped** to
satisfy Android 10's Treble/VNDK rules. Those deviations are documented below
and are matched by entries in the device tree's `proprietary-files.txt`.

## Contents

| Path                   | Description                                                        |
| ---------------------- | ------------------------------------------------------------------ |
| `proprietary/`         | the adapted stock dump: `vendor/...` blobs plus selected `/system` blobs (MediaTek native libraries, repacked APKs, stub jars) |
| `CPH1909-vendor.mk`    | `PRODUCT_COPY_FILES` list (~1480 rules) + `PRODUCT_PACKAGES` for the prebuilt APKs |
| `Android.mk`           | prebuilt APK modules (`BUILD_PREBUILT`, all `LOCAL_CERTIFICATE := platform`) |
| `Android.bp`           | generated Soong namespace                                          |
| `BoardConfigVendor.mk` | generated, empty                                                   |

Vendor blobs live under `proprietary/vendor/...` and install to
`$(TARGET_COPY_OUT_VENDOR)/...`. Files taken from the stock system partition
live under `proprietary/system/...` and install to
`$(TARGET_COPY_OUT_SYSTEM)/...`, **except** a few that are deliberately
relocated to `/vendor` (see "ELF dependency closure and VNDK fixes" below);
those use a `src:dst` remap in `proprietary-files.txt`.

## How it was generated

From a dump of the matching CPH1909 firmware containing both `vendor/` and
`system/` directories:

```sh
device/oppo/CPH1909/extract-files.sh /path/to/rom-dump
```

That runs the LineageOS `tools/extract-utils` helper and, as a final step,
`setup-makefiles.sh`, which writes the makefiles/bp listed above. The committed
tree then carries the manual adaptations described next; `proprietary-files.txt
` is kept in sync so regeneration reproduces them (with the noted exceptions).

## Manual deviations from the generated output

`CPH1909-vendor.mk` and `Android.mk` are marked "DO NOT MODIFY" by the
generator, but both were hand-patched and the changes committed. The device
tree's `proprietary-files.txt` was updated to match, so re-running
`setup-makefiles.sh` no longer emits the broken rules.

### A. Blobs dropped because they are built from source elsewhere

Stock blobs that Android 10 / LineageOS builds itself, or that the device tree
replaces with a source-built HAL, are **not** shipped (shipping them would
either duplicate a build target or install an incompatible 8.1 module to the
same path):

* **Generic AOSP duplicates.** `libstdc++.so`, the 64-bit
  `libclang_rt.ubsan_standalone` runtime, `vendor/bin/{grep,sh,toybox_vendor}`,
  `vndservice`/`vndservicemanager` (+ their init rc), `hw/gralloc.default.so`,
  `libeffects.so`, `mediacas/libclearkeycasplugin.so`, and the
  `soundfx/lib{bundlewrapper,downmix,effectproxy,ldnhncr,reverbwrapper,visualizer}.so`
  wrappers. All are produced by `base_system.mk`/`base_vendor.mk`; the stock
  copies only created duplicate-rule warnings.
* **The proprietary lights HAL.** `android.hardware.light@2.0-service-mediatek`,
  `android.hardware.light@2.0-impl-mediatek.so` and `lights.mt6765.so`
  (lib/lib64) plus the stock service rc. The device tree builds a custom
  `android.hardware.light@2.0-service.CPH1909` (`light/`) that drives
  `/sys/class/leds/lcd-backlight` directly. CPH1909 registers only the LCD
  backlight (no notification LED, no button backlight), so nothing is lost.
* **The legacy power HALs.** `hw/power.mt6765.so` / `power.default.so` are not
  imported: the device tree builds its own `power.mt6765` shim (API 0.3, writes
  `/proc/touchpanel/double_tap_enable` for double-tap-to-wake). The stock
  modules would install to the same path and cannot do DT2W.
* **`vendor/data/misc/ProjectConfig.mk`.** An MTK *build-time* config fragment
  with no runtime purpose; removed.
* **`vendor/etc/NOTICE.xml.gz`** (build-generated; copying it creates a ninja
  dependency cycle), the stock **VINTF** data, the **8.1 SELinux policy**,
  `mkshrc`, and `fs_config*` — see the `proprietary-files.txt` header.
* The `/system/vendor` copy of **`aurisys_config.xml`** was reverted (the
  vendor copy is the one used).

The stock OPPO **fingerprint** HIDL services (`fps_hal`, `fpay_hal`) are
disabled by override rc files in the device tree; the Silead sensor is served
by the AOSP `fingerprint@2.1-service` through the device tree's
`fingerprint.mt6765` shim. Their system-side interface libraries
(`android.frameworks.fingerprintservice@1.0.so`,
`vendor.oppo.hardware.biometrics.fingerprint@2.1.so`/`fingerprintpay@1.0.so`,
`libfpspolicy_fw.so`) are therefore not imported.

### B. Prebuilt APKs (repacked and re-signed)

Prebuilt APKs are **not** copied via `PRODUCT_COPY_FILES` (LineageOS 17.1
rejects `%.apk` entries there). They are `BUILD_PREBUILT` modules in
`Android.mk`, added to `PRODUCT_PACKAGES` in `CPH1909-vendor.mk`, all with
`LOCAL_CERTIFICATE := platform` (not `PRESIGNED`).

* **Nine vendor apps** under `/vendor/app`: `EmCamera`, `LPPeService`,
  `LocationEM2`, `MMIGroup`, `MTKLoggerProxy`, `NlpService`, `RootPA`,
  `WapiCertManager`, `sileadManager` (`LOCAL_VENDOR_MODULE := true`).
* **`SysuiDarkThemeOverlay`** under `/vendor/overlay`. The extract-utils helper
  does not generate vendor/overlay modules, so this stanza is maintained by
  hand and must be re-added if the tree is regenerated from scratch.
* **System APKs:** `SoterService` (`/system/app`), `ImsService` and
  `OppoSimSettings` (`/system/priv-app`, `LOCAL_PRIVILEGED_MODULE := true`,
  `LOCAL_DEX_PREOPT := false`).

**Why re-sign:** the stock APKs carry OPPO's platform certificate, which cannot
match an unofficial LineageOS build. Several apps join a platform shared user
(`LPPeService`, `MMIGroup`, `NlpService`, `WapiCertManager`, `sileadManager`,
`SoterService`, `OppoSimSettings` → `android.uid.system`; `EmCamera`,
`ImsService` → `android.uid.phone`); without re-signing the package manager
rejects them at boot for a shared-user signature mismatch.
`SysuiDarkThemeOverlay` must likewise match SystemUI's signature.

**Why repack:** `SoterService`, `ImsService`, `OppoSimSettings` and `EmCamera`
are dex-stripped in the stock image — their bytecode lives only in
`oat/arm64/*.vdex`, paired with Android 8.1 quickened odex that ART 10 cannot
read. The committed APKs carry an unquickened `classes.dex` extracted from those
vdex files (recipes below); the stock `oat/` artifacts are not shipped (a
pre-existing `oat/` directory also stops `installd` regenerating it). The stock
v1 signature (`META-INF/`) is dropped so the build's platform key applies.

### C. System-side imports kept at stock locations

* **SoterService** (`com.tencent.soter.soterserver`,
  `sharedUserId=android.uid.system`) is the app-side counterpart of the
  Trustonic Soter HAL (`vendor/bin/hw/vendor.trustonic.soter@1.0-service`,
  `vendor.qti.hardware.soter@1.0::ISoter`). The HIDL interface library
  `vendor.qti.hardware.soter@1.0.so` is kept at its stock `/system/lib[64]`
  location.
* **IMS (VoLTE):** `ImsService` (`com.mediatek.ims`) and `OppoSimSettings`
  (`com.coloros.simsettings`), repacked/re-signed like SoterService. This
  mirrors how MTK reference trees wire IMS, but a dump-based port has no access
  to the MTK IMS framework source, so the stock APKs are imported instead.
  Alongside them: `system/lib/libimsma*.so` (32-bit), `system/bin/vtservice`
  (32-bit) with its dependency closure (`libmtk_vt_service.so`, `libsource.so`,
  `libcomutils.so`, `libdpframework_mtk.so`, `libged_sys.so`,
  `libgralloc_extra_sys.so`, `libion_mtk_sys.so`, `libion_ulit_sys.so`,
  `libpq_prot_mtk.so`, `libsignal.so`, `libvt_avsync.so`) and the `/system`
  copies of the `vendor.mediatek.hardware.{videotelephony@1.0,pq@2.0,power@1.1}`
  HIDL interface libraries; 309-byte stub jars (`ims-common.jar`,
  `mediatek-ims-common.jar`, `com.coloros.statistics.jar`, `coloros.support.jar`,
  `com.nearme.romupdate.bugly.jar`); and
  `system/etc/permissions/com.coloros.libraries.xml`. Both IMS APKs'
  `<uses-library>` entries are `required="false"`. Their signature|privileged
  permissions are allowlisted by the device tree's
  `configs/permissions/privapp-permissions-ims.xml`.
* **Fingerprint/face framework stub jars** (309-byte empty jars):
  `android.frameworks.fingerprintservice-V1.0-java.jar`,
  `vendor.oppo.hardware.biometrics.fingerprint-V2.1-java.jar`,
  `ifaamanager.jar`, `android.frameworks.faceservice-V1.0-java.jar`,
  `vendor.oppo.hardware.biometrics.face-V1.0-java.jar`. Stock-layout parity;
  nothing in this ROM loads them. `ifaamanager.jar` is declared a public library
  by `system/etc/permissions/org.ifaa.android.manager.permissions.xml`. The face
  HIDL interface itself is built from source in the device tree
  (`interfaces/vendor/hardware/biometrics/face/1.0/`), and
  `android.frameworks.faceservice@1.0.so` is shipped for the stock `face_hal`
  backend that the source-built face proxy forwards to.
* **MediaTek `/system` native libraries** (audio, Bluetooth, DRM, NVRAM, display,
  radio, GNSS, camera, etc.) are kept in `proprietary/system/` and copied to the
  system partition, not relocated to `/vendor`. This includes
  `vendor.mediatek.hardware.camera.device@1.1.so` (a direct camera-stack
  dependency). The API-27 MediaTek framework JARs and precompiled ART/OAT/VDEX
  artifacts are excluded (tied to the stock framework/runtime).

### D. ELF dependency closure and VNDK fixes

Android 10 merged/removed several platform libraries and enforces Treble linker
namespaces, so a number of 8.1 blobs needed `DT_NEEDED` repairs (via `patchelf`)
and a few compatibility libraries had to be shipped. All were verified against
the built image's dependency closure.

* **`libbase-v28.so`** — the Android 8.1 `libbase` (from
  `prebuilts/vndk/v28`, copied by the **device tree** into `/vendor/lib[64]` and
  `/system/lib[64]`, not by this repo). Blobs that import the 5-argument
  `android::base::LogMessage` constructor removed in AOSP 10
  (`android.hardware.sensors@1.0-impl-mediatek`, `libnvram`, `libsysenv`,
  `android.hardware.drm@1.0-service.widevine`,
  `android.hardware.wifi@1.0-service`) had `DT_NEEDED libbase.so` rewritten to
  `libbase-v28.so`.
* **`libutilscallstack.so`** — added (`--add-needed`) to the camera libraries
  that import `android::CallStack` (`gralloc.mt6765`, `hwcomposer.mt6765`,
  `libsrv_um`, `libion_ulit`, `libmtkcam_stdutils`, `libmtkcam_debugutils`).
  The library itself is platform VNDK.
* **The libskia trio** — `libskia.so`, `libMMListParser.so`,
  `libgraphics2d_ext.so` (stock 8.1). `libhwuiext.so` `DT_NEEDED`s `libskia.so`,
  which in turn needs the two MTK-only libraries. They are extracted from the
  stock `/system/lib[64]` but installed **only to `/vendor/lib[64]`** via a
  `system/...:vendor/...` remap in `proprietary-files.txt` (AOSP `libhwui` links
  skia statically, so nothing in `/system` loads the shared libskia; a `/system`
  copy would only add a reverse-Treble dependency).
* **`libLLVM.so`** (stock, `/vendor/lib64`) — `vendor/bin/rs2spir` needs it;
  AOSP 10 renamed its LLVM to `libLLVM_android.so`, so the legacy name is shipped
  vendor-local (the vendor namespace cannot reach a non-delegated system lib).
* **`libsuspend.so`** (stock 32-bit, `/system/lib`) — `system/bin/kpoc_charger`
  (the KPOC charger blob) needs it; AOSP 10 builds libsuspend statically.
* **`libbacktrace.so` + `libunwind.so`** (stock, `/vendor/lib[64]`) —
  `aee_aedv`/`aee_aedv64`/`libudf` call `Backtrace::Create`, which AOSP 10's
  libbacktrace no longer exports compatibly; the stock pair is shipped
  vendor-local (`libbacktrace` → `libunwind` → `liblzma`, all within VNDK).
* **`liblog-v28.so`** (stock 8.1 `liblog`, soname rewritten to `liblog-v28.so`,
  `/vendor/lib[64]`) — `aee_aedv` imports the legacy logprint API
  (`android_log_format_*`, `android_log_printLogLine`, …) removed in AOSP 10;
  its `DT_NEEDED liblog.so` was rewritten to `liblog-v28.so`.
* **VNDK namespace `DT_NEEDED` trims** (`--remove-needed` / `--replace-needed`)
  so vendor processes only reference vendor-local or LLNDK/VNDK-delegated libs:
  `sound_trigger.primary.mt6765` and `audio.usb.mt6765` (drop
  `libaudioclient`/`libmedia`), `libabfadp`/`libfactoryfmjni` (drop `libmedia`),
  the OPPO face service (drop `libkeystore_binder`), `libPolarrRender`/`libmpbase`
  (drop `libandroid`), and `libwapi` (`libkeystore_binder` →
  `libkeystore-wifi-hidl`, which exports `keystore_get`). These links were
  no-ops or only `__aeabi_*` helpers already provided by libc.

### E. Other shipped fixes

* **`vendor/etc/public.libraries.txt`** — the stock vendor public-library list
  is shipped so the linker exposes the MTK vendor libraries to apps.
* **KPOC charger** — `system/bin/kpoc_charger` + rc and `libshowlogo.so` /
  `libsysenv_system.so` imported for charger mode.
* **init rc adaptation** (in the blob rc files): absolute import paths,
  `mount_all` split into early/late stages, A/B boot-region support removed,
  legacy sdcard symlinks / CD-ROM mount removed, dead factory/meta tools and rc
  removed.

## Repacking the APKs

`SoterService`, `ImsService`, `OppoSimSettings` and `EmCamera` are repacked the
same way. `vdexExtractor` is a host tool built from
<https://github.com/anestisb/vdexExtractor> (`./make.sh gcc`).

```sh
# 1. Unquicken the stock vdex (example: SoterService).
mkdir -p /tmp/repack
vdexExtractor -i /path/to/dump/system/app/SoterService/oat/arm64/SoterService.vdex \
    -o /tmp/repack -f
# /tmp/repack/SoterService_classes.dex now has a valid checksum and signature.

# 2. Rebuild the APK from the stock manifest/resources plus that dex. Drop
#    META-INF: the build replaces the OPPO signature with the platform key.
#    classes.dex and resources.arsc stay uncompressed (STORED), as in stock.
python3 - <<'PY'
import zipfile

src = '/path/to/dump/system/app/SoterService/SoterService.apk'
dst = 'vendor/oppo/CPH1909/proprietary/system/app/SoterService/SoterService.apk'
dex = '/tmp/repack/SoterService_classes.dex'

with zipfile.ZipFile(src) as zin:
    entries = [(i, zin.read(i.filename)) for i in zin.infolist()
               if not i.filename.startswith('META-INF/')]
with zipfile.ZipFile(dst, 'w') as zout:
    for info, data in entries:
        comp = zipfile.ZIP_STORED if info.filename in ('resources.arsc',) else zipfile.ZIP_DEFLATED
        zout.writestr(info.filename, data, comp)
    zout.writestr('classes.dex', open(dex, 'rb').read(), zipfile.ZIP_STORED)
PY
```

For the IMS APKs swap the paths to
`system/priv-app/{ImsService,OppoSimSettings}/...` (both
`LOCAL_PRIVILEGED_MODULE := true`); for `EmCamera` to
`vendor/app/EmCamera/...`. Both IMS APKs' `<uses-library>` entries are
`required="false"` (verified from the binary manifests), so neither library needs
to exist for the applications to install.

## Regenerating

```sh
device/oppo/CPH1909/setup-makefiles.sh
```

should re-emit:

* APKs as prebuilt modules from `proprietary-files.txt` (each APK entry omits
  `;PRESIGNED`, so the generator emits `LOCAL_CERTIFICATE := platform`),
  **except** `SysuiDarkThemeOverlay.apk`, which the generator ignores — keep the
  `PRODUCT_PACKAGES += SysuiDarkThemeOverlay` and its `BUILD_PREBUILT` stanza by
  hand.
* The Soter / IMS `/system` entries (interface-library copy rules, stub jars,
  permissions, and the repacked privileged modules).
* The fingerprint/face framework stubs and their permissions XML.
* The `src:dst` remaps for the libskia trio (extract from stock `/system`,
  install to `/vendor`).
* No `NOTICE.xml.gz`, VINTF, 8.1 SELinux, `mkshrc` or `fs_config*` copy rules.

Re-running `extract-files.sh` overwrites the repacked APKs with the stock
dex-stripped ones — **re-apply the repack** whenever the tree is re-extracted.
The `patchelf` `DT_NEEDED` edits and the added compatibility libraries
(`libLLVM`, `libsuspend`, `libbacktrace`, `libunwind`, `liblog-v28`, the libskia
trio) are committed blob changes; re-extraction restores the unpatched stock
files, so re-apply those edits too (they are recorded in the git history).

Before trusting a regenerated tree, check:

```sh
grep '\.apk.*TARGET_COPY_OUT_VENDOR' CPH1909-vendor.mk          # should be empty
grep 'NOTICE\.xml\.gz' CPH1909-vendor.mk                        # should be empty
grep -E 'lights\.mt6765|light@2\.0-impl-mediatek' CPH1909-vendor.mk  # should be empty
unzip -l proprietary/system/app/SoterService/SoterService.apk   # must list classes.dex
grep -A12 'LOCAL_MODULE := SoterService' Android.mk             # must say platform
grep -A13 'LOCAL_MODULE := ImsService' Android.mk               # platform, privileged
grep 'LOCAL_CERTIFICATE := PRESIGNED' Android.mk                # should be empty
readelf -d proprietary/vendor/lib64/hw/android.hardware.sensors@1.0-impl-mediatek.so | grep base  # libbase-v28
```

## Notes

* The blob list (`proprietary-files.txt`) is owned by the **device tree**, not
  this repository. Its header documents the deliberate exclusions (VINTF, 8.1
  SELinux, `mkshrc`, build-generated `public.libraries.txt`/`fs_config*`/
  `NOTICE.xml.gz`).
* `vendor/etc/permissions/pms_sysapp_removable_vendor_list.txt` and
  `vendor/etc/ipsec/ssl/openssl.cnf` are zero-length in the stock dump and are
  carried over as-is.
* `setup-makefiles.sh` in the device tree must be executable (mode 100755), as
  `extract-files.sh` invokes it directly.
* The source-built HALs (fingerprint, power, lights, face) and the device-side
  sepolicy/overlay/ramdisk live in the device tree; this repository only carries
  the blobs they depend on.
