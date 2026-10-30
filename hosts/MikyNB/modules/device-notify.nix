# Desktop notification + sound whenever a USB device is physically
# plugged in or removed. Bluetooth connect/disconnect is handled
# separately in home/modules/device-notify.nix - that one runs inside the
# user's own session (watching BlueZ over D-Bus) and so needs none of the
# root -> user-session bridging this file exists for.
{ pkgs, ... }:

let
  sounds = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo";

  # udev RUN+= rules execute as root with no session at all - no
  # XDG_RUNTIME_DIR, no D-Bus, nothing notify-send/canberra-gtk-play need
  # to reach the real desktop. This bridges into the actual user session
  # the same way hosts/MikyNB/modules/power-button.nix's
  # power-button-menu service does (runuser + explicit env vars) - minus
  # the Wayland/niri-socket bits that one needs and this one doesn't,
  # since notify-send/canberra-gtk-play only need D-Bus and the
  # PipeWire-Pulse socket, both reachable once XDG_RUNTIME_DIR and
  # DBUS_SESSION_BUS_ADDRESS are set.
  #
  # Takes the device name as however many words it comes in as ($2
  # onward joined back together) rather than a single pre-joined
  # argument, so a vendor/model string containing spaces (udev's RUN+=
  # splits on whitespace with no quoting of its own) doesn't get mangled
  # into the wrong positions.
  notifyScript = pkgs.writeShellScript "device-notify" ''
    set -euo pipefail
    action="$1"
    shift
    name="$*"
    [ -z "$name" ] && name="Unknown device"

    title="Device connected"
    sound="${sounds}/device-added.oga"
    if [ "$action" = "removed" ]; then
      title="Device disconnected"
      sound="${sounds}/device-removed.oga"
    fi

    runtime_dir=/run/user/1000

    ${pkgs.util-linux}/bin/runuser -u miky8745 -- \
      ${pkgs.coreutils}/bin/env \
        XDG_RUNTIME_DIR="$runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
        ${pkgs.libnotify}/bin/notify-send -i drive-removable-media "$title" "$name"
    ${pkgs.util-linux}/bin/runuser -u miky8745 -- \
      ${pkgs.coreutils}/bin/env \
        XDG_RUNTIME_DIR="$runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
        ${pkgs.libcanberra-gtk3}/bin/canberra-gtk-play -f "$sound"
  '';
in
{
  services.udev.extraRules = ''
    # ENV{DEVTYPE}=="usb_device" matches the whole physical device exactly
    # once; without it, every interface of a multi-function device (e.g.
    # a webcam's separate video/audio/HID interfaces) would each fire
    # their own add/remove, turning one physical plug/unplug into a burst
    # of duplicate notifications and overlapping sounds.
    SUBSYSTEM=="usb", ACTION=="add", ENV{DEVTYPE}=="usb_device", RUN+="${pkgs.systemd}/bin/systemd-run --quiet --no-block ${notifyScript} added $env{ID_VENDOR_FROM_DATABASE} $env{ID_MODEL_FROM_DATABASE}"
    SUBSYSTEM=="usb", ACTION=="remove", ENV{DEVTYPE}=="usb_device", RUN+="${pkgs.systemd}/bin/systemd-run --quiet --no-block ${notifyScript} removed $env{ID_VENDOR_FROM_DATABASE} $env{ID_MODEL_FROM_DATABASE}"
  '';
}
