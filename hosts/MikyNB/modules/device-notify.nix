# Desktop notification + sound whenever a USB device is physically
# plugged in or removed. Bluetooth connect/disconnect is handled
# separately in home/modules/device-notify.nix - that one runs inside the
# user's own session (watching BlueZ over D-Bus) and so needs none of the
# root -> user-session bridging this file exists for.
{ pkgs, ... }:

let
  # KDE Plasma's current default sound theme ("ocean") - same package
  # home/modules/device-notify.nix's Bluetooth sounds and niri.nix's
  # volume-change sound now use too. power-plug/power-unplug (rather than
  # this theme's device-added/device-removed, which the Bluetooth module
  # uses) is the pair KDE itself reserves for an actual physical cable
  # being plugged/unplugged, as opposed to a device merely becoming
  # logically available - matching exactly what's going on here.
  sounds = "${pkgs.kdePackages.ocean-sound-theme}/share/sounds/ocean/stereo";

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
  # Name resolution used to join $env{ID_VENDOR_FROM_DATABASE} and
  # $env{ID_MODEL_FROM_DATABASE} - udev's hwdb lookup of the vendor:product
  # ID pair against a static USB-ID database. That database doesn't cover
  # every vendor ID (e.g. this laptop's own USB mouse's vendor ID has no
  # entry at all), so for a lot of real devices one or both of those come
  # back empty, which is where "Unknown device" was coming from - and even
  # when populated, ID_VENDOR_FROM_DATABASE alone (with no model) reads as
  # just the manufacturer, not the device.
  #
  # $env{ID_MODEL_ENC}/$env{ID_VENDOR_ENC} instead come straight from the
  # device's own USB string descriptors (set by its firmware, read by
  # udev's usb_id builtin) rather than a lookup table, so they're present
  # for far more devices - and ID_MODEL_ENC in particular is the actual
  # product name ("USB Gaming Mouse", "HP HD Camera"), which is the device
  # name asked for here, not the manufacturer. The FROM_DATABASE fields are
  # kept as a secondary fallback for the rare device with no USB string
  # descriptors at all.
  #
  # None of the above are actually available on a remove event in
  # practice, though - confirmed via `journalctl`, which showed every
  # remove invocation getting called with those fields completely empty
  # (`device-notify removed "|"`), while the matching add always has them.
  # Likely usb_id/hwdb need sysfs attributes that are already gone by the
  # time udev gets around to running this RUN+= rule for remove - but
  # whatever the exact cause, there's no device info to read at remove
  # time, full stop. So instead: cache the name resolved at add time to a
  # file keyed by $kernel (e.g. "1-4", udev's own name for the physical
  # device, derived straight from the uevent rather than any builtin/hwdb
  # lookup - available unconditionally on both add and remove), then read
  # that cache back on remove instead of trying to resolve anything fresh.
  #
  # ID_MODEL_ENC/ID_VENDOR_ENC are individually whitespace-free (spaces
  # come through as literal "\x20" escapes, decoded below with
  # `printf %b`) - but either one can still be entirely *empty* (e.g. a
  # device with a product string but no manufacturer string, or vice
  # versa), and udev's RUN+= just splits its command line on whitespace
  # with no concept of an empty argument - an empty $env{} expansion
  # doesn't produce an empty word, it vanishes, shifting every argument
  # after it one slot to the left. Reading these as two fixed positional
  # params would silently desync the moment either one is empty on some
  # device. Joined with a literal "|" instead (below), there's always
  # exactly one word here no matter which side is empty - bash does the
  # splitting instead of udev, on a character udev's own splitting never
  # touches.
  notifyScript = pkgs.writeShellScript "device-notify" ''
    set -euo pipefail
    action="$1"
    kernel="$2"
    encoded="$3"
    shift 3
    db_name="$*"
    model_enc="''${encoded%%|*}"
    vendor_enc="''${encoded#*|}"

    cache_dir="/run/device-notify-cache"
    cache_file="$cache_dir/$kernel"

    # udev RUN+= (via systemd-run) hands this script essentially no PATH,
    # unlike an interactive shell - every external command needs its full
    # store path, same as notify-send/canberra-gtk-play/pw-play already
    # get below. mkdir/cat/rm here were bare names and failed outright
    # with "command not found", silently killing the whole script before
    # it ever got to notify-send or pw-play - which is why both the
    # notification *and* the sound went missing entirely, not just the
    # name text.
    if [ "$action" = "removed" ]; then
      name="Unknown device"
      [ -f "$cache_file" ] && name="$(${pkgs.coreutils}/bin/cat "$cache_file")"
      ${pkgs.coreutils}/bin/rm -f "$cache_file"
    else
      name="$(printf '%b' "$model_enc")"
      [ -z "$name" ] && name="$db_name"
      [ -z "$name" ] && name="$(printf '%b' "$vendor_enc")"
      [ -z "$name" ] && name="Unknown device"
      ${pkgs.coreutils}/bin/mkdir -p "$cache_dir"
      printf '%s' "$name" > "$cache_file"
    fi

    title="Device connected"
    sound="${sounds}/power-plug.oga"
    if [ "$action" = "removed" ]; then
      title="Device disconnected"
      sound="${sounds}/power-unplug.oga"
    fi

    runtime_dir=/run/user/1000

    ${pkgs.util-linux}/bin/runuser -u miky8745 -- \
      ${pkgs.coreutils}/bin/env \
        XDG_RUNTIME_DIR="$runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
        ${pkgs.libnotify}/bin/notify-send -i drive-removable-media "$title" "$name"
    # canberra-gtk-play (used here previously) links GTK, which tries to
    # open an X11/Wayland display to initialize - something this root ->
    # user-session bridge never sets up (only XDG_RUNTIME_DIR + D-Bus
    # above), so it was silently failing ("Cannot open display: ") and no
    # sound ever played. pw-play talks to PipeWire directly over the
    # socket under XDG_RUNTIME_DIR - no display needed, same bridge as
    # notify-send above already provides.
    ${pkgs.util-linux}/bin/runuser -u miky8745 -- \
      ${pkgs.coreutils}/bin/env \
        XDG_RUNTIME_DIR="$runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
        ${pkgs.pipewire}/bin/pw-play "$sound"
  '';
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
