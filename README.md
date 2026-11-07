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
| `proprietary/`       | 1463 blobs copied verbatim from the stock vendor image   |
| `CPH1909-vendor.mk`  | `PRODUCT_COPY_FILES` list + `PRODUCT_PACKAGES` override  |
| `Android.mk`         | prebuilt APK modules (`BUILD_PREBUILT`)                  |
| `Android.bp`         | generated Soong namespace                                 |
| `BoardConfigVendor.mk` | generated, empty                                         |

The blobs are laid out under `proprietary/vendor/...` and installed to the
vendor partition (`$(TARGET_COPY_OUT_VENDOR)/...`).

## How it was generated

From a dump of the matching CPH1909 firmware containing a `vendor/` directory:

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

1. **Prebuilt APKs are no longer copied via `PRODUCT_COPY_FILES`**
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

2. **`vendor/etc/NOTICE.xml.gz` is not shipped.** The Android 10 build
   generates `NOTICE.xml.gz`; copying the stock precompiled copy on top of it
   creates a ninja dependency cycle
   (`vendor/etc/NOTICE.xml.gz -> obj/NOTICE_VENDOR.xml.gz -> ...`) and fails
   the build. It is removed from both the blob list and the copy rules.

3. The prebuilt-APK modules and the `NOTICE.xml.gz` removal are the only
   functional deviations; the rest of the tree is the verbatim stock dump.

## Regenerating

```sh
device/oppo/CPH1909/setup-makefiles.sh
```

should now re-emit:

* APKs as prebuilt modules from `proprietary-files.txt` (each APK entry is
  prefixed with `-` and marked `;PRESIGNED`), **except**
  `SysuiDarkThemeOverlay.apk`, which is still ignored by the generator and
  needs keeping the `PRODUCT_PACKAGES += SysuiDarkThemeOverlay` and the
  overlay `BUILD_PREBUILT` stanza in this repository.
* No `NOTICE.xml.gz` copy rule.

Before trusting a regenerated tree, check:

```sh
grep '\.apk.*TARGET_COPY_OUT_VENDOR' CPH1909-vendor.mk      # should be empty
grep 'NOTICE\.xml\.gz' CPH1909-vendor.mk                    # should be empty
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
* `build/core/config.mk` re-asserts `TARGET_KERNEL_SOURCE` after LineageOS's
  `BoardConfigKernel.mk` clears it (that file unconditionally empties
  `TARGET_KERNEL_SOURCE` whenever `TARGET_PREBUILT_KERNEL` is set, even for a
  prebuilt kernel image). This matters because LineageOS's
  `generated_kernel_includes` Soong module runs
  `make -C $(TARGET_KERNEL_SOURCE) ... headers_install` for modules that
  depend on `generated_kernel_headers`; an empty `TARGET_KERNEL_SOURCE` makes
  that `make -C` fail with "No such file or directory". The kernel image
  itself stays prebuilt; a separate kernel source tree
  (`leonardrua/A5S-8.1-kernel-source`, synced into `kernel/oppo/CPH1909` by
  the CI build workflow) is used **only** to satisfy that header-install call.
  This hook is pulled in via `-include vendor/*/build/core/config.mk`, which
  runs after all board config has been processed, so the re-asserted value is
  what LineageOS's `BoardConfigSoong.mk` actually exports to the Soong
  `lineageVarsPlugin`.
