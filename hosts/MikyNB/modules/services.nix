{ ... }:

{
  # ---------- Services ----------
  services.power-profiles-daemon.enable = true;
  services.fstrim.enable = true;
  services.fwupd.enable = true;
  services.flatpak.enable = true;
  services.openssh.enable = false; # set true if you want to SSH *into* this laptop
  hardware.xpadneo.enable = true; # Xbox controllers over Bluetooth

  # Tray applet + GUI (pairing, connect/disconnect) for the Bluetooth stack
  # enabled in audio.nix. Registers as a StatusNotifierItem, picked up by
  # waybar's "tray" module (see home/modules/waybar.nix) automatically.
  services.blueman.enable = true;
}
