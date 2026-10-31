# Desktop notification + sound whenever a USB device is physically
# plugged in or removed. Bluetooth connect/disconnect is handled
# separately in home/modules/device-notify - that one runs inside the
# user's own session (watching BlueZ over D-Bus) and so needs none of the
# root -> user-session bridging this file exists for.
#
# The udev-triggered shell script itself lives in notify-script.nix.
{ pkgs, ... }:

let
  notifyScript = import ./notify-script.nix { inherit pkgs; };
in
{
  services.udev.extraRules = ''
    # ENV{DEVTYPE}=="usb_device" matches the whole physical device exactly
    # once; without it, every interface of a multi-function device (e.g.
    # a webcam's separate video/audio/HID interfaces) would each fire
    # their own add/remove, turning one physical plug/unplug into a burst
    # of duplicate notifications and overlapping sounds.
    SUBSYSTEM=="usb", ACTION=="add", ENV{DEVTYPE}=="usb_device", RUN+="${pkgs.systemd}/bin/systemd-run --quiet --no-block ${notifyScript} added $kernel $env{ID_MODEL_ENC}|$env{ID_VENDOR_ENC} $env{ID_VENDOR_FROM_DATABASE} $env{ID_MODEL_FROM_DATABASE}"
    SUBSYSTEM=="usb", ACTION=="remove", ENV{DEVTYPE}=="usb_device", RUN+="${pkgs.systemd}/bin/systemd-run --quiet --no-block ${notifyScript} removed $kernel $env{ID_MODEL_ENC}|$env{ID_VENDOR_ENC} $env{ID_VENDOR_FROM_DATABASE} $env{ID_MODEL_FROM_DATABASE}"
  '';
}
