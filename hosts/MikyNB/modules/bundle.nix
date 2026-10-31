{ ... }:

{
  imports = [
    ./boot.nix
    ./power-button
    ./nvidia.nix
    ./networking.nix
    ./locale.nix
    ./cursor.nix
    ./fonts.nix
    ./qt.nix
    ./desktop.nix
    ./audio.nix
    ./printing.nix
    ./services.nix
    ./btrfs.nix
    ./virtualisation.nix
    ./programs.nix
    ./user.nix
    ./packages.nix
    ./nix.nix
    ./device-notify
  ];
}
