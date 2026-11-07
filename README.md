# OPPO A5s (CPH1909) vendor blobs — LineageOS 17.1

Proprietary vendor components for the OPPO A5s / CPH1909 (MediaTek MT6765,
Helio P35), extracted from the stock ColorOS 5.2 / Android 8.1 (API 27) firmware
dump.

This repository is the `vendor/oppo/CPH1909` half of the port. The matching
device tree lives in `android_device_oppo_CPH1909` and is cloned to
`device/oppo/CPH1909`; its `device.mk` pulls this tree in with

```make
$(call inherit-product-if-exists, vendor/oppo/CPH1909/CPH1909-vendor.mk)
```

## Contents

| Path                 | Description                                              |
| -------------------- | -------------------------------------------------------- |
| `proprietary/`       | 1464 blobs copied verbatim from the stock vendor image   |
| `CPH1909-vendor.mk`  | generated `PRODUCT_COPY_FILES` list (installs the blobs) |
| `Android.mk`         | generated, currently empty (no `-`-packaged modules)     |
| `Android.bp`         | generated Soong namespace                                |
| `BoardConfigVendor.mk` | generated, empty                                       |

The blobs are laid out under `proprietary/vendor/...` and installed to the
vendor partition (`$(TARGET_COPY_OUT_VENDOR)/...`).

## How it was generated

From a dump of the matching CPH1909 firmware containing a `vendor/` directory:

```sh
device/oppo/CPH1909/extract-files.sh /path/to/rom-dump
```

That runs the LineageOS `tools/extract-utils` helper and, as a final step,
`setup-makefiles.sh`, which writes the makefiles listed above.

## Notes

* The blob list (`proprietary-files.txt`) is owned by the device tree, not this
  repository. It deliberately excludes the stock VINTF data, the 8.1 SELinux
  policy, `mkshrc`, and the build-generated `public.libraries.txt`/`fs_config*`
  files; see the header of that file.
* `vendor/etc/permissions/pms_sysapp_removable_vendor_list.txt` and
  `vendor/etc/ipsec/ssl/openssl.cnf` are zero-length in the stock dump and are
  carried over as-is.
* `setup-makefiles.sh` in the device tree must be executable (mode 100755), as
  `extract-files.sh` invokes it directly.
