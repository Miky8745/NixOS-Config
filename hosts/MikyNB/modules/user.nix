{ pkgs, ... }:

{
  # ---------- User ----------
  users.users.miky8745 = {
    isNormalUser = true;
    description = "Miky";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel" "networkmanager" "docker" "vboxusers"
      "dialout" # serial ports / Arduino (was uucp on Arch)
      "scanner" "lp"
    ];
  };
}
