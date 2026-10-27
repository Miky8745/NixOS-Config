# Declarative disk layout for the internal NVMe (used by disko at install time,
# and to generate fileSystems/swapDevices for the system).
# WARNING: running disko with this file ERASES the whole disk.
let
  btrfsOpts = [ "compress=zstd" "noatime" ];
in
{
  disko.devices.disk.main = {
    type = "disk";
    # by-id so it can never hit the Windows disks (sda/sdb) by accident
    device = "/dev/disk/by-id/nvme-Vi3000_Internal_PCIe_NVMe_M.2_SSD_1TB_4937552548309745";
    content = {
      type = "gpt";
      partitions = {
        # Tiny partition where BIOS GRUB embeds itself (GPT has no MBR gap).
        # disko also sets boot.loader.grub.devices to this disk because of it.
        bios = {
          size = "1M";
          type = "EF02";
        };
        # A plain partition is simpler than a btrfs swapfile and keeps hibernation easy.
        swap = {
          size = "17G";
          content.type = "swap";
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" "-L" "nixos" ];
            # All subvolumes share the free space of the partition.
            subvolumes = {
              "@root" = {
                mountpoint = "/";
                mountOptions = btrfsOpts;
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = btrfsOpts;
              };
              # Snapper keeps /home snapshots here (appears as /home/.snapshots).
              "@home/.snapshots" = { };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = btrfsOpts;
              };
              # VM / emulator disk images: kept out of /home snapshots and
              # set to no-copy-on-write (+C) in configuration.nix.
              "@vms" = {
                mountpoint = "/home/miky8745/VMs";
                mountOptions = [ "noatime" ];
              };
            };
          };
        };
      };
    };
  };
}
