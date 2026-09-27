$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, vendor/lineage/config/common_full_tablet.mk)
$(call inherit-product, device/realme/RMP6768/device.mk)

PRODUCT_DEVICE := RMP6768
PRODUCT_NAME := evo_RMP6768
PRODUCT_BRAND := Realme
PRODUCT_MANUFACTURER := Realme
PRODUCT_MODEL := Realme Pad

BUILD_FINGERPRINT := "realme/RMP2102/RE54C1L1:11/RP1A.200720.011/1677153829078:user/release-keys"
PRODUCT_BUILD_PROP_OVERRIDES := PRIVATE_BUILD_DESC="full_oppo8786-user 11 RP1A.200720.011 816 release-keys"
PRODUCT_GMS_CLIENTID_BASE := android-realme
