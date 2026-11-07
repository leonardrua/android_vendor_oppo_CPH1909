# Reassert TARGET_KERNEL_SOURCE after LineageOS's BoardConfigKernel.mk
# clears it. That file sets TARGET_KERNEL_SOURCE := (empty) whenever
# TARGET_PREBUILT_KERNEL is non-empty, even when a prebuilt kernel image
# is being used. The generated_kernel_includes Soong module still needs a
# real kernel source directory for its `make -C $(TARGET_KERNEL_SOURCE)
# headers_install` call (required by modules that depend on
# generated_kernel_headers), so point it back at the synced kernel tree.
#
# The kernel image itself remains the prebuilt one; this tree (cloned
# separately into the build tree by the CI workflow) is used only for
# header installation. This hook runs later than BoardConfigKernel.mk
# because it is pulled in via -include vendor/*/build/core/config.mk,
# which fires after all board config has been processed.
ifneq ($(TARGET_PREBUILT_KERNEL),)
_kdir := $(shell echo $(TARGET_DEVICE_DIR) | sed -e 's/^device/kernel/g')
TARGET_KERNEL_SOURCE := $(_kdir)
endif
