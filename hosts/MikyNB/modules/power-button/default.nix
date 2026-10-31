# Power button handling, split into the three independent pieces that
# make it work:
# - kernel.nix: retargets the kernel's raw ACPI power-button signal
# - menu-service.nix: the systemd service that opens wlogout in response
# - polkit.nix: the polkit rule letting that wlogout instance actually
#   suspend/reboot/poweroff
{ ... }:

{
  imports = [
    ./kernel.nix
    ./menu-service.nix
    ./polkit.nix
  ];
}
