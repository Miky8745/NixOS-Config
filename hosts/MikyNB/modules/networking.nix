{ pkgs, ... }:

{
  # ---------- Networking ----------
  networking.hostName = "MikyNB";
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [ networkmanager-openvpn networkmanager-openconnect ];
  };
  networking.firewall.enable = true; # replaces firewalld/ufw
  networking.wireguard.enable = true;

  # Single biggest userspace boot-time item (`systemd-analyze blame`:
  # 5.4s), and nothing on this machine needs confirmed network
  # connectivity before considering boot "done" - NetworkManager itself
  # still starts and connects in the background regardless of this.
  systemd.services.NetworkManager-wait-online.enable = false;
}
