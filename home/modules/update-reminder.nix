# Desktop notification + sound once a week has passed since flake.lock was
# last regenerated, nagging to run the CVE/security update routine. A plain
# `rebuild-nixos` (nh os switch) rebuilds from whatever flake.lock already
# pins and never touches it, so tracking the system profile symlink would
# reset the clock on every rebuild even when no package actually got newer -
# only `nix flake update` moves the pins, so flake.lock's own mtime is the
# thing worth watching. Unlike device-notify (which reacts to a Bluetooth
# D-Bus signal or a udev hotplug event), there's no event to watch here -
# this just has to check the clock once a day, so a plain systemd user timer
# does the whole job with no separate watcher process.
{ pkgs, ... }:

let
  # Same sound theme family as device-notify's USB/Bluetooth sounds and
  # niri.nix's volume-change sound.
  sound = "${pkgs.kdePackages.ocean-sound-theme}/share/sounds/ocean/stereo/dialog-warning.oga";

  flakeLock = "/home/miky8745/Programming/nixos_conf/flake.lock";

  checkScript = pkgs.writeShellScript "nixos-update-reminder" ''
    set -euo pipefail

    last=$(${pkgs.coreutils}/bin/stat -c %Y "${flakeLock}")
    now=$(${pkgs.coreutils}/bin/date +%s)
    age_days=$(( (now - last) / 86400 ))

    if [ "$age_days" -ge 7 ]; then
      ${pkgs.libnotify}/bin/notify-send -u critical -i software-update-urgent \
        "NixOS update overdue" \
        "$age_days days since flake.lock was last updated - run nix flake update && sudo nixos-rebuild switch as soon as possible."
      ${pkgs.pipewire}/bin/pw-play "${sound}"
    fi
  '';
in
{
  systemd.user.services.nixos-update-reminder = {
    Unit = {
      Description = "Nag about an overdue NixOS rebuild";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${checkScript}";
    };
  };

  systemd.user.timers.nixos-update-reminder = {
    Unit = {
      Description = "Daily check for an overdue NixOS rebuild";
    };
    Timer = {
      OnCalendar = "daily";
      # Catches up on first login after the laptop was off/asleep through
      # the scheduled time, instead of silently skipping that day's check.
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
