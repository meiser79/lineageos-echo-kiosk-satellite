#
# What the Echo Spot (1st gen) gets on top of the amazon-oss rook tree.
# stage-tree.sh copies device/rook/ to device/kiosk-satellite/rook in the
# tree.
#

# The network name EchoService gives the Spot: echo-spot-ks and the end of
# its serial.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.echo.hostname=echo-spot-ks

# Kiosk Satellite's MIC capture stays raw, as on the Echo Shows: microphone
# 0 as captured, so Kiosk Satellite's own echo canceller sees the speaker's
# echo at a fixed delay. Any echo canceller, suppressor or gain control ahead
# of it changes that echo as it adapts, and Kiosk Satellite's canceller never
# settles. The Spot's FPGA sends four microphones and the copy of the speaker
# signal in a six channel stream, as the Echo Show 8's does.
#
# The Kiosk Satellite Edition's echo canceller (common/audio/amznaec) stays
# loaded but passes the microphones through. persist.vendor.amznaec.enable 1
# brings it back with the Echo Show 5's settings: engine 2, then 20 dB of
# gain, since the Spot's analog microphone gain is Amazon's MICPGA 40
# (audio_device.xml), as on the Show 5.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.vendor.amznaec.enable=0 \
    ro.vendor.amznaec.engine=2 \
    ro.vendor.amznaec.gain_db=20

# Amazon's ASR and Voice pipelines in passthrough, as on the Echo Show 5: its
# own echo canceller, beamformer and level normalization would change the
# echo as they adapt. The Spot has no EchoParts, so the HAL wrapper sends every plain mic
# capture to the Voice pipeline, whose AGC the passthrough leaves out. The
# Spot's libasp predates the Shows' asp.cfg and reads the switch from these
# properties instead.
PRODUCT_PROPERTY_OVERRIDES += \
    persist.asp.asr.passthrough=true \
    persist.asp.voice.passthrough=true

# Media volume 10 of 15 on a fresh install, which Kiosk Satellite shows as
# 70%, as on the Echo Show 5.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.media_vol_default=10

# Android's usual button, as the Spot has no privacy chip and no light to
# show privacy: a short press turns the screen on and off, holding it opens
# the power menu. echo_service button press makes a hold do nothing.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.echo.button_long_press=1

# Balanced BLE scans in short windows, which EchoService sets on a fresh
# install. Android's balanced scan, the default of Kiosk Satellite's
# Bluetooth proxy, scans for a second every four, and the Spot's Broadcom
# controller holds the A2DP link back for about 135 ms at a time during that
# second, so both Bluetooth directions stuttered. The same share of airtime
# in 30 ms windows leaves it room. A scan without pause, low latency, which
# Kiosk Satellite calls Continuous, plays cleanly as it is.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.echo.ble_scan_balanced_window_ms=30 \
    ro.echo.ble_scan_balanced_interval_ms=120
