{ pkgs, ... }:

{
  # ---------- Programs ----------
  # Needed so zsh can be a login shell; the actual config lives in Home Manager
  # (home/miky8745.nix), so plugins are not enabled here to avoid loading them twice.
  programs.zsh.enable = true;
  programs.firefox.enable = true;
  programs.steam.enable = true;
  programs.appimage = {
    enable = true;
    binfmt = true; # run AppImages directly
  };
  # Lets prebuilt Linux binaries (Unity editor, Arduino toolchains, pip wheels...)
  # find their libraries even though NixOS has no /lib.
  programs.nix-ld.enable = true;
}
