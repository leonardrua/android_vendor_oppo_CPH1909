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
# header installation.
ifneq ($(TARGET_PREBUILT_KERNEL),)
    _kdir := $(shell echo $(TARGET_DEVICE_DIR) | sed -e 's/^device/kernel/g')
    ifeq ($(TARGET_KERNEL_SOURCE),)
        TARGET_KERNEL_SOURCE := $(_kdir)
    endif
    ifneq ($(TARGET_KERNEL_SOURCE),)
        SOONG_CONFIG_lineageVarsPlugin_TARGET_KERNEL_SOURCE := $(TARGET_KERNEL_SOURCE)
    endif
endif
