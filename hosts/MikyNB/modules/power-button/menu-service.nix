{ pkgs, ... }:

{
  # Fires every time the kernel asks for "start default.target" (every
  # power-button press, and every nixos-rebuild switch - see above). No
  # `RemainAfterExit`, so it resets to inactive after each run and is
  # ready to fire again.
  systemd.services.power-button-menu = {
    description = "Open the wlogout power menu (triggered by the ACPI power button via tiny_power_button's retargeted signal)";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Default KillMode (control-group) kills every process still in this
      # unit's cgroup the moment the oneshot's ExecStart (the runuser/
      # wlogout chain below) finishes - which happens almost immediately,
      # since wlogout closes its own window and then just detach-spawns the
      # clicked action rather than waiting on it. Suspend/reboot/poweroff
      # survive that teardown because systemctl's D-Bus call to logind is
      # already accepted before the kill lands; the Lock button doesn't -
      # qylock-lock's chain (lock.sh -> quickshell lock_shell.qml) *is* a
      # long-running process that has to keep existing after this unit is
      # "done", and was instead getting SIGKILLed mid-startup (confirmed via
      # `journalctl -u power-button-menu`: "Killed" / exit 137, right after
      # lock.sh's last "Theme path: ..." log line, before quickshell's lock
      # screen ever appeared). KillMode=process limits the kill to the one
      # PID systemd tracks as this unit's main process, leaving whatever it
      # detached-spawned alone.
      KillMode = "process";
    };
    script = ''
      runtime_dir=/run/user/1000
      wayland_sock=$(${pkgs.coreutils}/bin/ls "$runtime_dir"/wayland-* 2>/dev/null | ${pkgs.coreutils}/bin/head -n1)
      # niri's IPC socket, needed for wlogout's "logout" action (`niri msg
      # action quit -s`, see home/modules/wlogout.nix) to find niri at all -
      # without NIRI_SOCKET set, niri msg fails outright with "NIRI_SOCKET
      # is not set, are you running this within niri?" (confirmed via
      # `journalctl -u power-button-menu`). Named after the Wayland display
      # socket it sits next to, same directory.
      niri_sock=$(${pkgs.coreutils}/bin/ls "$runtime_dir"/niri.wayland-*.sock 2>/dev/null | ${pkgs.coreutils}/bin/head -n1)
      # Forced rather than left to qylock's own lock.sh, which tries to
      # self-detect this via `loginctl show-session ... -p Type` - but
      # that queries whatever logind session runuser itself just opened
      # below (a throwaway PAM session, not the real graphical one), and
      # its detection chain also silently breaks here anyway (no awk on
      # this service's restricted PATH). Getting anything other than the
      # literal string "wayland" makes qylock's lock_shell.qml skip its
      # real Wayland session-lock surface (WlSessionLock, backed by
      # ext-session-lock-v1 - the thing niri actually enforces, blocking
      # input/window-switching while locked) in favor of its X11 fallback
      # branch: a plain top-level window with no protocol backing it at
      # all, dismissible with an ordinary niri keybind like Mod+Left/
      # Right (confirmed - this was exactly the "lock opens a window but
      # Mod+Left/Right gets you right back in" symptom). Forcing it
      # directly here is simpler and more reliable than fixing lock.sh's
      # own detection, and correct by construction: this whole branch only
      # runs once a real Wayland socket was already found above.
      if [ -n "$wayland_sock" ]; then
        ${pkgs.util-linux}/bin/runuser -u miky8745 -- \
          ${pkgs.coreutils}/bin/env XDG_RUNTIME_DIR="$runtime_dir" \
            WAYLAND_DISPLAY="$(${pkgs.coreutils}/bin/basename "$wayland_sock")" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
            NIRI_SOCKET="$niri_sock" \
            XDG_SESSION_TYPE="wayland" \
            ${pkgs.wlogout}/bin/wlogout -b 3
      fi
    '';
  };
}
