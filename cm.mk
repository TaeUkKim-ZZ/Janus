# Inherit AOSP device configuration for streak.
$(call inherit-product, device/kttech/janus/janus.mk)

# Inherit some common CM stuff.
$(call inherit-product, vendor/cm/config/common_full_phone.mk)

## Specify phone tech before including full_phone
$(call inherit-product, vendor/cm/config/gsm.mk)

#
# Setup device specific product configuration.
#
PRODUCT_NAME := cm_janus
PRODUCT_BRAND := kttech
PRODUCT_DEVICE := janus
PRODUCT_MODEL := JANUS
PRODUCT_MANUFACTURER := KTTECH
PRODUCT_BUILD_PROP_OVERRIDES += PRODUCT_NAME=janus BUILD_FINGERPRINT=kttech/janus/janus:4.0.4/IMM76I/330937:user/release-keys PRIVATE_BUILD_DESC="janus-user 4.0.4 IMM76I 330937 release-keys"
