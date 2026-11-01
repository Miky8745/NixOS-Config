# Desktop notification + sound once a week has passed since the last
# successful `nixos-rebuild switch`, nagging to run the CVE/security
# update routine. Unlike device-notify (which reacts to a Bluetooth D-Bus
# signal or a udev hotplug event), there's no event to watch here - this
# just has to check the clock once a day, so a plain systemd user timer
# does the whole job with no separate watcher process.
{ pkgs, ... }:

let
  # Same sound theme family as device-notify's USB/Bluetooth sounds and
  # niri.nix's volume-change sound.
  sound = "${pkgs.kdePackages.ocean-sound-theme}/share/sounds/ocean/stereo/dialog-warning.oga";

  checkScript = pkgs.writeShellScript "nixos-update-reminder" ''
    set -euo pipefail

    # /nix/var/nix/profiles/system is re-pointed with ln -sfn on every
    # successful nixos-rebuild switch, so the symlink's own mtime (not its
    # target's - store paths are all stamped to epoch+1 for reproducibility)
    # is a reliable "time of last successful rebuild". stat defaults to
    # lstat for a symlink argument, so --no-dereference below is just
    # making that explicit, not changing behaviour.
    last=$(${pkgs.coreutils}/bin/stat -c %Y --no-dereference /nix/var/nix/profiles/system)
    now=$(${pkgs.coreutils}/bin/date +%s)
    age_days=$(( (now - last) / 86400 ))

    if [ "$age_days" -ge 7 ]; then
      ${pkgs.libnotify}/bin/notify-send -u critical -i software-update-urgent \
        "NixOS update overdue" \
        "$age_days days since your last rebuild - run nix flake update && sudo nixos-rebuild switch as soon as possible."
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
