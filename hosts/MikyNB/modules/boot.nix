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
  boot.kernelPackages = pkgs.linuxPackages.extend (
    # Our Xbox Wireless Controller (model 1708) sends a truncated 306-byte
    # HID report descriptor over Bluetooth with newer firmware, which the
    # nixpkgs-pinned xpadneo 0.10.2 can't parse ("unbalanced collection at
    # end of report description" / probe failed with error -22) - BlueZ
    # connects and then drops it a few seconds later since no driver binds.
    # Fixed upstream (atar-axis/xpadneo#636/#624) after the 0.10.2 tag;
    # pull in that fix until it lands in a tagged release.
    _final: prev: {
      xpadneo = prev.xpadneo.overrideAttrs (_old: {
        version = "unstable-2026-11-17";
        src = pkgs.fetchFromGitHub {
          owner = "atar-axis";
          repo = "xpadneo";
          rev = "56b538d951300bf804f6631738603c5eb14c04f0";
          hash = "sha256-94uJ8fyFFrijoQ3+ldTO15oswSPwFY3m4p8dzY94ZKU=";
        };
      });
    }
  ); # NixOS default = LTS kernel, with xpadneo overridden (see above)
  boot.supportedFilesystems = [ "ntfs" ];

  # Default is 5s; cut to 2 - short enough to not meaningfully add to boot
  # time, long enough to still interrupt and pick Windows from the
  # os-prober entry when needed.
  boot.loader.timeout = 2;
}
