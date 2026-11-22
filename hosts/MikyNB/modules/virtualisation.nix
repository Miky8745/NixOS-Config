{ ... }:

{
  # ---------- Virtualisation ----------
  virtualisation.docker.enable = true;
  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.virtualbox.host.enable = true;

  # vboxnet0 is recreated by the kernel module during switch; systemd can
  # race trying to restart the address unit before the device re-appears,
  # which fails activation even though the service self-heals moments later.
  systemd.services.network-addresses-vboxnet0.restartIfChanged = false;
}
