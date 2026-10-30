# Desktop notification + sound on Bluetooth device connect/disconnect.
# USB hotplug gets the same treatment but is handled on the system side
# (hosts/MikyNB/modules/device-notify.nix) via a udev rule - Bluetooth
# connect/disconnect isn't a udev-visible hotplug event (the device
# itself was already enumerated at pairing time; only BlueZ's own
# Device1.Connected property flips), so this instead watches that over
# D-Bus. Runs as a user service, so unlike the USB side it talks to
# notify-send/canberra-gtk-play directly - no root -> user-session
# bridging needed.
{ pkgs, ... }:

let
  # KDE Plasma's current default sound theme ("ocean") - same package
  # referenced from niri.nix's volumePreviewCmd and
  # hosts/MikyNB/modules/device-notify.nix's USB sounds, for a consistent
  # set across all three instead of mixing in sound-theme-freedesktop's.
  sounds = "${pkgs.kdePackages.ocean-sound-theme}/share/sounds/ocean/stereo";
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.dbus-next ]);
in
{
  xdg.configFile."bluetooth-notify/watch.py" = {
    executable = true;
    text = ''
      #!/usr/bin/env python3
      # Watches BlueZ over the system D-Bus for Device1.Connected flipping
      # on any already-paired device, and fires a desktop notification +
      # sound each time it does. Monitoring broadcast signals like this
      # needs no special privileges - it's the same mechanism nm-applet
      # (home/modules/niri.nix) already relies on for NetworkManager's own
      # system-bus signals.
      import asyncio
      import subprocess

      from dbus_next import BusType
      from dbus_next.aio import MessageBus

      NOTIFY_SEND = "${pkgs.libnotify}/bin/notify-send"
      CANBERRA_PLAY = "${pkgs.libcanberra-gtk3}/bin/canberra-gtk-play"
      SOUND_CONNECTED = "${sounds}/device-added.oga"
      SOUND_DISCONNECTED = "${sounds}/device-removed.oga"


      def notify(connected, name):
          title = "Bluetooth connected" if connected else "Bluetooth disconnected"
          sound = SOUND_CONNECTED if connected else SOUND_DISCONNECTED
          icon = "bluetooth-active" if connected else "bluetooth-disabled"
          subprocess.Popen([NOTIFY_SEND, "-i", icon, title, name])
          subprocess.Popen([CANBERRA_PLAY, "-f", sound])


      async def watch_device(bus, path):
          introspection = await bus.introspect("org.bluez", path)
          obj = bus.get_proxy_object("org.bluez", path, introspection)
          device = obj.get_interface("org.bluez.Device1")
          props = obj.get_interface("org.freedesktop.DBus.Properties")
          name = await device.get_alias()

          def on_properties_changed(interface, changed, invalidated):
              if interface == "org.bluez.Device1" and "Connected" in changed:
                  notify(changed["Connected"].value, name)

          props.on_properties_changed(on_properties_changed)


      async def main():
          bus = await MessageBus(bus_type=BusType.SYSTEM).connect()

          introspection = await bus.introspect("org.bluez", "/")
          root = bus.get_proxy_object("org.bluez", "/", introspection)
          object_manager = root.get_interface("org.freedesktop.DBus.ObjectManager")

          objects = await object_manager.call_get_managed_objects()
          for path, interfaces in objects.items():
              if "org.bluez.Device1" in interfaces:
                  await watch_device(bus, path)

          def on_interfaces_added(path, interfaces):
              if "org.bluez.Device1" in interfaces:
                  asyncio.ensure_future(watch_device(bus, path))

          object_manager.on_interfaces_added(on_interfaces_added)

          await asyncio.get_event_loop().create_future()  # run forever


      if __name__ == "__main__":
          asyncio.run(main())
    '';
  };

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
