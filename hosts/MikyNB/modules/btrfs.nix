{ ... }:

{
  # ---------- Btrfs snapshots (snapper) ----------
  # Hourly snapshots of /home; restore with `snapper -c home list` / `snapper -c home undochange`,
  # or just copy files out of /home/.snapshots/<n>/snapshot/.
  services.snapper.configs.home = {
    SUBVOLUME = "/home";
    ALLOW_USERS = [ "miky8745" ];
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = 24;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 4;
    TIMELINE_LIMIT_MONTHLY = 0;
    TIMELINE_LIMIT_YEARLY = 0;
  };
  services.btrfs.autoScrub.enable = true; # monthly checksum check of all data

  # Snapshots don't include nested subvolumes, so big, constantly changing
  # folders get their own subvolume ("v") to keep them out of /home snapshots.
  systemd.tmpfiles.rules = [
    # The VMs mount below creates /home/miky8745 as root before the user exists; fix ownership
    "d /home/miky8745 0700 miky8745 users -"
    "d /home/miky8745/.local 0755 miky8745 users -"
    "d /home/miky8745/.local/share 0755 miky8745 users -"
    "v /home/miky8745/.cache 0700 miky8745 users -"
    "v /home/miky8745/.local/share/Steam 0755 miky8745 users -"
    # VMs subvolume (from disko): owned by the user, no copy-on-write for new files
    "d /home/miky8745/VMs 0755 miky8745 users -"
    "h /home/miky8745/VMs - - - - +C"
  ];
}
