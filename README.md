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
| `proprietary/`       | 1466 files: the stock vendor dump plus 3 Soter `/system` files (1 repacked APK + 2 interface libraries) |
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

2. **Prebuilt APKs are no longer copied via `PRODUCT_COPY_FILES`**
   (LineageOS 17.1 rejects `%.apk` entries there with
   `Prebuilt apk found in PRODUCT_COPY_FILES ...`): the 9 vendor apps
   (`EmCamera`, `LPPeService`, `LocationEM2`, `MMIGroup`, `MTKLoggerProxy`,
   `NlpService`, `RootPA`, `WapiCertManager`, `sileadManager`) and
   `SysuiDarkThemeOverlay` are `BUILD_PREBUILT` modules in `Android.mk` and
   are added to `PRODUCT_PACKAGES` in `CPH1909-vendor.mk`. All are
   `PRESIGNED`, `LOCAL_VENDOR_MODULE=true`, installed under `/vendor/app`;
   the overlay installs under `/vendor/overlay`. `EmCamera`'s precompiled
   `oat/arm64/EmCamera.odex`/`.vdex` remain plain `PRODUCT_COPY_FILES`.

   **SysuiDarkThemeOverlay.apk** is kept as a module, not a copy, for the
   same reason; the extract-utils helper does not generate vendor/overlay
   modules, so this stanza in `Android.mk` is maintained by hand and must be
   re-added by hand if the vendor tree is regenerated from scratch.

3. **`vendor/etc/NOTICE.xml.gz` is not shipped.** The Android 10 build
   generates `NOTICE.xml.gz`; copying the stock precompiled copy on top of it
   creates a ninja dependency cycle
   (`vendor/etc/NOTICE.xml.gz -> obj/NOTICE_VENDOR.xml.gz -> ...`) and fails
   the build. It is removed from both the blob list and the copy rules.

4. The SoterService import and the prebuilt-APK modules/`NOTICE.xml.gz` removal are the only
   functional deviations; the rest of the tree is the verbatim stock dump.

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
  is prefixed with `-` and marked `;PRESIGNED`), **except**
  `SysuiDarkThemeOverlay.apk`, which is still ignored by the generator and
  needs keeping the `PRODUCT_PACKAGES += SysuiDarkThemeOverlay` and the
  overlay `BUILD_PREBUILT` stanza in this repository.
* The Soter `/system` entries: the interface-library copy rules and the
  `SoterService` module, including `LOCAL_CERTIFICATE := platform` (the
  generator signs APK entries without `;PRESIGNED` with the platform key).
* No `NOTICE.xml.gz` copy rule.

Re-running `extract-files.sh` also overwrites
`proprietary/system/app/SoterService/SoterService.apk` with the stock
dex-stripped APK. Re-apply the repack above whenever the tree is extracted
again.

Before trusting a regenerated tree, check:

```sh
grep '\.apk.*TARGET_COPY_OUT_VENDOR' CPH1909-vendor.mk      # should be empty
grep 'NOTICE\.xml\.gz' CPH1909-vendor.mk                    # should be empty
unzip -l proprietary/system/app/SoterService/SoterService.apk   # must list classes.dex
grep -A12 'LOCAL_MODULE := SoterService' Android.mk         # must say platform
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
