#
# What the Echo Spot (1st gen) gets on top of the amazon-oss rook tree.
# stage-tree.sh copies device/rook/ to device/kiosk-satellite/rook in the
# tree.
#

# The network name EchoService gives the Spot: echo-spot-ks and the end of
# its serial.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.echo.hostname=echo-spot-ks

# Echo cancellation on the microphones (common/audio/amznaec), with the
# Echo Show 5's engine and gain to start from. The Spot's FPGA sends four
# microphones and the copy of the speaker signal in a six channel stream, as
# the Echo Show 8's does, and its analog microphone gain is Amazon's MICPGA
# 40 (audio_device.xml), as on the Show 5. The Show 8 now sends its captures
# through Amazon's ASR pipeline instead (ro.vendor.audio.asr_capture, a
# patch to the audio HAL wrapper the Spot shares), which the Spot does not
# take on before it is measured here.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.vendor.amznaec.engine=2 \
    ro.vendor.amznaec.gain_db=20

# Amazon's ASR and Voice pipelines in passthrough, as on the Echo Show 5: its
# own echo canceller, beamformer and level normalization fought the one
# above. The Spot has no EchoParts, so the HAL wrapper sends every plain mic
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
