{ pkgs, ... }:

{
  # ---------- Printing / scanning (Canon via cnijfilter2) ----------
  services.printing = {
    enable = true;
    drivers = [ pkgs.cnijfilter2 ];
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  hardware.sane.enable = true;
}
