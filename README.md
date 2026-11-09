# OPPO A5s (CPH1909) vendor blobs — LineageOS 17.1

Proprietary vendor components for the OPPO A5s / CPH1909 (MediaTek MT6765,
Helio P35), extracted from the stock ColorOS 5.2 / Android 8.1 (API 27)
firmware dump.

This repository is the `vendor/oppo/CPH1909` half of the port. The matching
device tree lives in `android_device_oppo_CPH1909` and is cloned to
`device/oppo/CPH1909`; its `device.mk` pulls this tree in with

```make
$(call inherit-product-if-exists, vendor/oppo/CPH1909/CPH1909-vendor.mk)
```

## Contents

| Path                 | Description                                              |
| -------------------- | -------------------------------------------------------- |
| `proprietary/`       | the stock vendor dump plus the `/system` blobs described below (2 repacked IMS APKs + 4 `libimsma*.so` + 5 framework/permission files) |
| `CPH1909-vendor.mk`  | `PRODUCT_COPY_FILES` list + `PRODUCT_PACKAGES` override  |
| `Android.mk`         | prebuilt APK modules (`BUILD_PREBUILT`)                  |
| `Android.bp`         | generated Soong namespace                                 |
| `BoardConfigVendor.mk` | generated, empty                                         |

The vendor blobs are laid out under `proprietary/vendor/...` and installed to
the vendor partition (`$(TARGET_COPY_OUT_VENDOR)/...`). The few files taken
from the stock system partition live under `proprietary/system/...` and are
installed to `$(TARGET_COPY_OUT_SYSTEM)/...`.

## How it was generated

From a dump of the matching CPH1909 firmware containing both `vendor/` and
`system/` directories:

```sh
device/oppo/CPH1909/extract-files.sh /path/to/rom-dump
```

That runs the LineageOS `tools/extract-utils` helper and, as a final step,
`setup-makefiles.sh`, which writes the makefiles/bp listed above.

## Manual deviations from the generated output

`CPH1909-vendor.mk` and `Android.mk` are marked "DO NOT MODIFY" by the
generator, but both were hand-patched and the changes committed. The
`device/oppo/CPH1909/proprietary-files.txt` list was updated to match, so
re-running `setup-makefiles.sh` no longer emits the broken rules.

1. **`SoterService` is imported from the stock `/system` partition.**
   `com.tencent.soter.soterserver` runs with `sharedUserId=android.uid.system`
   in `/system/app` and is the app-side counterpart of the Trustonic Soter HAL
   (`vendor/bin/hw/vendor.trustonic.soter@1.0-service`, implementing
   `vendor.qti.hardware.soter@1.0::ISoter`). It exposes the
   `com.tencent.soter.soterserver.ISoterService` binder service used by apps
   for Soter biometric authentication (e.g. WeChat fingerprint payment). It is
   a `BUILD_PREBUILT` module in `Android.mk` and is **not** a vendor module,
   so it installs into `/system/app`.

   Two things differ from a plain stock APK import:

   * **The APK is repacked.** The stock APK is dex-stripped: its bytecode
     lives only in `oat/arm64/SoterService.vdex`, paired with an Android 8.1
     quickened odex that the Android 10 runtime cannot use. The committed APK
     carries an unquickened `classes.dex` extracted from that vdex (see the
     repack recipe below), and the stock odex/vdex are deliberately not
     shipped.
   * **The build re-signs it.** `LOCAL_CERTIFICATE := platform`, not
     `PRESIGNED`: an unofficial LineageOS build's platform key does not match
     OPPO's stock certificate, and the package manager rejects a
     `sharedUserId=android.uid.system` app whose signature differs from the
     platform's. The repacked APK therefore has no `META-INF/` and is signed
     during the build.

   `vendor.qti.hardware.soter@1.0.so`, the HIDL interface library the HAL
   links against, is kept at its stock `/system/lib[64]` location (not
   `/vendor/lib[64]`) and copied there by `CPH1909-vendor.mk`.

1a. **The stock IMS (VoLTE) system blobs are imported.** This mirrors how
   MTK reference device trees wire IMS (e.g. `Xiaomi/dandelion`,
   `Redmi/begonia`): they add `PRODUCT_BOOT_JARS`/`PRODUCT_PACKAGES` entries
   for MTK's IMS framework source (`mediatek-ims-base`, `mediatek-ims-common`,
   `ImsServiceBase`, ...) and `configs/permissions/*.xml` permission
   allowlists, and deliberately do NOT ship the dex-stripped
   `priv-app/ImsService` APK from the factory dump. A dump-based port has no
   access to that source, so the stock APKs are imported and repacked exactly
   like SoterService:

   * **ImsService** (`system/priv-app/ImsService/ImsService.apk`,
     `com.mediatek.ims`, `sharedUserId=android.uid.phone`) and
     **OppoSimSettings** (`system/priv-app/OppoSimSettings/OppoSimSettings.apk`,
     `com.coloros.simsettings`, `sharedUserId=android.uid.system`). The stock
     APKs are dex-stripped and their `oat/arm64/*.vdex` files hold Android 8.1
     quickened bytecode that the Android 10 runtime cannot execute, so the
     committed APKs carry unquickened `classes.dex` extracted from those
     vdex files (see the repack recipe below) and are re-signed with the
     build's platform key. They are privileged modules in `/system/priv-app`
     (`LOCAL_PRIVILEGED_MODULE := true`, `LOCAL_DEX_PREOPT := false`).
   * `system/lib/libimsma*.so` (32-bit only — MTK's IMS stack is 32-bit):
     the native libraries `libmtk_vt_service.so` links against. Inert while
     that JNI library is not shipped; kept for layout
     parity.
   * `system/bin/vtservice` (32-bit only) with its dependency closure
     installed at the stock `/system` locations: `libmtk_vt_service.so` plus
     `libsource.so`, `libcomutils.so`, `libdpframework_mtk.so`, `libged_sys.so`,
     `libgralloc_extra_sys.so`, `libion_mtk_sys.so`, `libion_ulit_sys.so`,
     `libpq_prot_mtk.so`, `libsignal.so` and `libvt_avsync.so`, plus the
     `/system` copies of the `vendor.mediatek.hardware.videotelephony@1.0`,
     `vendor.mediatek.hardware.pq@2.0` and
     `vendor.mediatek.hardware.power@1.1` HIDL interface libraries. This is
     what makes the `service vtservice /system/bin/vtservice` line in
     `init.vtservice.rc` startable. (Stock labels the binary `vtservice_exec`;
     this port labels it `mtk_vtservice_exec` and runs it permissive.)
   * `system/framework/ims-common.jar`, `mediatek-ims-common.jar`,
     `com.coloros.statistics.jar`, `coloros.support.jar`,
     `com.nearme.romupdate.bugly.jar`: 309-byte stub jars (empty manifest
     only) kept at their stock locations. Nothing in this build's boot
     classpath references them.
   * `system/etc/permissions/com.coloros.libraries.xml`: registers
     `com.coloros.statistics`, the library the OppoSimSettings
     `<uses-library>` declaration names. Both IMS APKs' `<uses-library>`
     entries are `required="false"` (verified from the binary manifests), so
     both applications install regardless; `com.mediatek.op.ims.common`
     (ImsService's `<uses-library>`) is not shipped because stock never
     shipped it either.
   * `com.mediatek.ims` and `com.coloros.simsettings` additionally need their
     signature|privileged permissions allowlisted; see
     `device/oppo/CPH1909/configs/permissions/privapp-permissions-ims.xml`
     (copied into `/system/etc/permissions/` by the device tree).

1b. **The stock fingerprint and face framework stubs are imported (system-side).**
   The 8.1 framework stub jars copied verbatim —
   `system/framework/android.frameworks.fingerprintservice-V1.0-java.jar`,
   `system/framework/vendor.oppo.hardware.biometrics.fingerprint-V2.1-java.jar`,
   `system/framework/ifaamanager.jar`,
   `system/framework/android.frameworks.faceservice-V1.0-java.jar` and
   `system/framework/vendor.oppo.hardware.biometrics.face-V1.0-java.jar` —
   are 309-byte empty jars (empty manifest only). No AOSP/LineageOS build
   module emits these paths, and nothing in this ROM loads them:
   `frameworks/base` builds the real fingerprint API into `framework.jar`.
   They are stock-layout parity. `ifaamanager.jar` (OPPO's IFAA framework) is
   declared a public library by
   `system/etc/permissions/org.ifaa.android.manager.permissions.xml`, same
   as in stock, and that file is imported with it. The face stub pair is the
   same stub for the OPPO face stack; the stock `face_hal` cannot load in
   this build (its `DT_NEEDED` system-side libs are deliberately not
   imported) and its service is disabled by an override rc in the device
   tree.

1c. **The stock fingerprint HAL chain.** The stock system-side interface
   libraries (`android.frameworks.fingerprintservice@1.0.so`,
   `vendor.oppo.hardware.biometrics.fingerprint@2.1.so`/`fingerprintpay@1.0.so`,
   `libfpspolicy_fw.so`) are deliberately NOT imported: their only consumers
   are the two stock OPPO fingerprint services, which the device tree
   disables via stub rc files (the Silead sensor is behind the AOSP
   `fingerprint@2.1-service` through `sileadManager.apk` + the
   `fingerprint.mt6765` shim). Similarly the stock `oat/arm(64)` versions of
   the stub jars are dropped — LineageOS builds its own boot artifacts.
   The stock legacy power HALs (`vendor/lib[64]/hw/power.mt6765.so` and
   `power.default.so`) are likewise NOT imported/installed: the device tree
   builds its own `power.mt6765` shim (DT2W writer for
   `/proc/touchpanel/double_tap_enable`), and the stock modules would install
   to the exact same path while being unable to do DT2W at all.
     `device/oppo/CPH1909/configs/permissions/privapp-permissions-ims.xml`
     (copied into `/system/etc/permissions/` by the device tree).

2. **Prebuilt APKs are no longer copied via `PRODUCT_COPY_FILES`**
   (LineageOS 17.1 rejects `%.apk` entries there with
   `Prebuilt apk found in PRODUCT_COPY_FILES ...`): the 9 vendor apps
   (`EmCamera`, `LPPeService`, `LocationEM2`, `MMIGroup`, `MTKLoggerProxy`,
   `NlpService`, `RootPA`, `WapiCertManager`, `sileadManager`) and
   `SysuiDarkThemeOverlay` are `BUILD_PREBUILT` modules in `Android.mk` and
   are added to `PRODUCT_PACKAGES` in `CPH1909-vendor.mk`. All use
   `LOCAL_CERTIFICATE := platform` (not `PRESIGNED`), `LOCAL_VENDOR_MODULE=true`
   and are installed under `/vendor/app`; the overlay installs under
   `/vendor/overlay`. `EmCamera`'s precompiled `oat/arm64/EmCamera.odex`/`.vdex`
   remain plain `PRODUCT_COPY_FILES`.

   The APKs are re-signed with the build's platform key rather than kept
   `PRESIGNED`: the stock files carry OPPO's platform certificate, which does
   not match an unofficial LineageOS build. Six of them join a platform
   shared user — `LPPeService`, `MMIGroup`, `NlpService`, `WapiCertManager`
   and `sileadManager` declare `sharedUserId=android.uid.system`, `EmCamera`
   declares `android.uid.phone` — so without re-signing the package manager
   would reject them at boot for a shared-user signature mismatch.
   `SysuiDarkThemeOverlay` likewise needs the build platform signature to
   match SystemUI.

   **SysuiDarkThemeOverlay.apk** is kept as a module, not a copy, for the
   same reason; the extract-utils helper does not generate vendor/overlay
   modules, so this stanza in `Android.mk` is maintained by hand and must be
   re-added by hand if the vendor tree is regenerated from scratch.

3. **`vendor/etc/NOTICE.xml.gz` is not shipped.** The Android 10 build
   generates `NOTICE.xml.gz`; copying the stock precompiled copy on top of it
   creates a ninja dependency cycle
   (`vendor/etc/NOTICE.xml.gz -> obj/NOTICE_VENDOR.xml.gz -> ...`) and fails
   the build. It is removed from both the blob list and the copy rules.

4. The SoterService import, the IMS imports, the fingerprint framework stubs and the prebuilt-APK modules/`NOTICE.xml.gz` removal are the only
   functional deviations; the rest of the tree is the verbatim stock dump.

### Repacking the IMS APKs

`ImsService.apk` and `OppoSimSettings.apk` are repacked the same way as
SoterService, with the roles of the paths swapped:

```sh
# 1. Unquicken the stock vdex files (vdexExtractor, see below).
mkdir -p /tmp/ims
vdexExtractor -i /path/to/dump/system/priv-app/ImsService/oat/arm64/ImsService.vdex -o /tmp/ims -f
vdexExtractor -i /path/to/dump/system/priv-app/OppoSimSettings/oat/arm64/OppoSimSettings.vdex -o /tmp/ims -f
# /tmp/ims/{ImsService_classes.dex,OppoSimSettings_classes.dex}

# 2. Rebuild each APK: every stock entry except META-INF/*, plus the
#    unquickened classes.dex (STORED). resources.arsc and classes.dex
#    stay uncompressed, everything else may follow the stock compression.
python3 - <<'PY'
import zipfile

for name in ('ImsService', 'OppoSimSettings'):
    src = f'/path/to/dump/system/priv-app/{name}/{name}.apk'
    dst = f'/home/asus/android_vendor_oppo_CPH1909/proprietary/system/priv-app/{name}/{name}.apk'
    dex = f'/tmp/ims/{name}_classes.dex'
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

Both APKs' `<uses-library>` entries are `required="false"` (verified from the
binary manifests), so neither library needs to exist for the applications to
install.

### Repacking SoterService

The committed APK is not the stock file. To recreate it from a firmware dump:

```sh
# 1. Unquicken the stock vdex. vdexExtractor is a host tool built from
#    https://github.com/anestisb/vdexExtractor (./make.sh gcc).
mkdir -p /tmp/soter
vdexExtractor -i /path/to/dump/system/app/SoterService/oat/arm64/SoterService.vdex \
    -o /tmp/soter -f
# /tmp/soter/SoterService_classes.dex now has a valid checksum and signature.

# 2. Rebuild the APK from the stock manifest/resources plus that dex. Drop
#    META-INF: the build replaces the OPPO signature with the platform key.
python3 - <<'PY'
import zipfile

src = '/path/to/dump/system/app/SoterService/SoterService.apk'
dst = 'vendor/oppo/CPH1909/proprietary/system/app/SoterService/SoterService.apk'
dex = '/tmp/soter/SoterService_classes.dex'

with zipfile.ZipFile(src) as zin:
    manifest = zin.read('AndroidManifest.xml')
    arsc = zin.read('resources.arsc')

with zipfile.ZipFile(dst, 'w') as zout:
    zout.writestr('AndroidManifest.xml', manifest, zipfile.ZIP_DEFLATED)
    zout.writestr('classes.dex', open(dex, 'rb').read(), zipfile.ZIP_STORED)
    zout.writestr('resources.arsc', arsc, zipfile.ZIP_STORED)
PY
```

`classes.dex` and `resources.arsc` stay uncompressed, as in the stock APK.

## Regenerating

```sh
device/oppo/CPH1909/setup-makefiles.sh
```

should now re-emit:

* APKs as prebuilt modules from `proprietary-files.txt` (each vendor APK entry
  is prefixed with `-` and carries no `;PRESIGNED` suffix, so the generator
  emits `LOCAL_CERTIFICATE := platform`), **except**
  `SysuiDarkThemeOverlay.apk`, which is still ignored by the generator and
  needs keeping the `PRODUCT_PACKAGES += SysuiDarkThemeOverlay` and the
  overlay `BUILD_PREBUILT` stanza in this repository.
* The Soter `/system` entries: the interface-library copy rules and the
  `SoterService` module, including `LOCAL_CERTIFICATE := platform` (the
  generator signs APK entries without `;PRESIGNED` with the platform key).
* The IMS `/system` entries: the `libimsma*.so`, stub-jar and permissions
  copy rules, plus the `ImsService`/`OppoSimSettings` privileged modules.
* The fingerprint framework stubs and their permissions XML copy rules.
* No `NOTICE.xml.gz` copy rule.

Re-running `extract-files.sh` also overwrites
`proprietary/system/app/SoterService/SoterService.apk` and
`proprietary/system/priv-app/{ImsService,OppoSimSettings}/.*\.apk` with the
stock dex-stripped APKs. Re-apply the repack above whenever the tree is
extracted again.

Before trusting a regenerated tree, check:

```sh
grep '\.apk.*TARGET_COPY_OUT_VENDOR' CPH1909-vendor.mk      # should be empty
grep 'NOTICE\.xml\.gz' CPH1909-vendor.mk                    # should be empty
unzip -l proprietary/system/app/SoterService/SoterService.apk   # must list classes.dex
grep -A12 'LOCAL_MODULE := SoterService' Android.mk         # must say platform
grep -A13 'LOCAL_MODULE := ImsService' Android.mk           # must say platform, private
grep -A13 'LOCAL_MODULE := OppoSimSettings' Android.mk      # must say platform, private
grep 'LOCAL_CERTIFICATE := PRESIGNED' Android.mk            # should be empty
```

## Notes

* The blob list (`proprietary-files.txt`) is owned by the device tree, not
  this repository. It deliberately excludes the stock VINTF data, the 8.1
  SELinux policy, `mkshrc`, and the build-generated `public.libraries.txt`/
  `fs_config*`/`NOTICE.xml.gz` files; see the header of that file.
* `vendor/etc/permissions/pms_sysapp_removable_vendor_list.txt` and
  `vendor/etc/ipsec/ssl/openssl.cnf` are zero-length in the stock dump and are
  carried over as-is.
* `setup-makefiles.sh` in the device tree must be executable (mode 100755), as
  `extract-files.sh` invokes it directly.
