{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./modules/bundle.nix
  ];

  # Set once at install time. Do NOT change it when upgrading NixOS.
  system.stateVersion = "26.05";
}
