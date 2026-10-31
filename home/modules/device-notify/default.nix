# Desktop notification + sound on Bluetooth device connect/disconnect.
# USB hotplug gets the same treatment but is handled on the system side
# (hosts/MikyNB/modules/device-notify.nix) via a udev rule - Bluetooth
# connect/disconnect isn't a udev-visible hotplug event (the device
# itself was already enumerated at pairing time; only BlueZ's own
# Device1.Connected property flips), so this instead watches that over
# D-Bus. Runs as a user service, so unlike the USB side it talks to
# notify-send/canberra-gtk-play directly - no root -> user-session
# bridging needed.
#
# The watcher script itself lives in watch-script.nix.
{ pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.dbus-next ]);
in
{
  imports = [ ./watch-script.nix ];

  # No home-manager module ships for this - same shape as
  # home/modules/swayosd.nix's swayosd-server service.
  systemd.user.services.bluetooth-notify = {
    Unit = {
      Description = "Desktop notification + sound on Bluetooth device connect/disconnect";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pythonEnv}/bin/python3 %h/.config/bluetooth-notify/watch.py";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
