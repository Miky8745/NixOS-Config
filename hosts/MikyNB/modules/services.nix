{ ... }:

{
  # ---------- Services ----------
  services.power-profiles-daemon.enable = true;
  services.fstrim.enable = true;
  services.fwupd.enable = true;
  services.flatpak.enable = true;
  services.openssh.enable = false; # set true if you want to SSH *into* this laptop
  hardware.xpadneo.enable = true; # Xbox controllers over Bluetooth
}
