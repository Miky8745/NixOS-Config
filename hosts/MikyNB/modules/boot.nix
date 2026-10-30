{ pkgs, ... }:

{
  # ---------- Boot ----------
  # The laptop boots in legacy BIOS mode (Windows on sdb is MBR/BIOS too),
  # so stay on BIOS GRUB to keep the Windows dual boot working.
  # The install disk is set by disko (EF02 partition in disko.nix).
  boot.loader.grub = {
    enable = true;
    useOSProber = true;
  };
  boot.kernelPackages = pkgs.linuxPackages; # NixOS default = LTS kernel
  boot.supportedFilesystems = [ "ntfs" ];

  # Default is 5s; cut to 2 - short enough to not meaningfully add to boot
  # time, long enough to still interrupt and pick Windows from the
  # os-prober entry when needed.
  boot.loader.timeout = 2;
}
