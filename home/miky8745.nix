# Home Manager: your user-level config (dotfiles, user programs).
# Each concern lives in its own file under ./modules; this is just the entrypoint.
{ ... }:

{
  imports = [
    ./modules/git.nix
    ./modules/zsh.nix
    ./modules/niri.nix
    ./modules/waybar.nix
    ./modules/wlogout.nix
    ./modules/fuzzel.nix
    ./modules/swaync.nix
    ./modules/swayidle.nix
    ./modules/swayosd.nix
    ./modules/alacritty.nix
    ./modules/theme.nix
    ./modules/environment.nix
    ./modules/mime.nix
  ];

  home.username = "miky8745";
  home.homeDirectory = "/home/miky8745";

  programs.home-manager.enable = true;

  # Same rule as system.stateVersion: set once, never change.
  home.stateVersion = "26.05";
}
