{ pkgs, ... }:

{
  # ---------- Power button ----------
  # This laptop's physical power button has no real ACPI control-method
  # device behind it (confirmed: dmesg's `button` driver only ever
  # registers Lid Switch and Sleep Button; also confirmed via the legacy
  # /proc/acpi/button/ procfs interface, which only has a `lid/` entry),
  # only the kernel's "fixed hardware" ACPI power event - so nothing at
  # the evdev/libinput level (logind, niri keybinds) or the ACPI netlink
  # level (acpid) ever sees anything for it. The only thing that reacts
  # at all is the kernel's "tiny_power_button" driver, whose `.notify()`
  # calls `kill_cad_pid(power_signal, 1)` - a raw signal straight to PID
  # 1, bypassing every userspace layer entirely.
  #
  # This is very likely a kernel regression, not a hardware limitation:
  # https://lkml.org/lkml/2025/12/15/991 converted drivers/acpi/button.c
  # to the platform-driver model (which needs a real ACPI namespace node
  # to bind to - a pure fixed-hardware button has none), where it
  # previously used the same direct ACPI-bus-notify style
  # tiny_power_button still uses, and *did* handle fixed-hardware buttons
  # correctly. This laptop's prior EndeavourOS/KDE install (which worked)
  # almost certainly predated that patch. Pinning to an older kernel
  # (linuxPackages_6_12 is available and predates it) would be the
  # "proper" fix, restoring native evdev/logind/niri handling - not done
  # here since it's a bigger, riskier change (whole-system kernel
  # version) than retargeting this one driver; revisit if ever wanted.
  #
  # `power_signal` is a runtime-writable module parameter, so the one
  # event this hardware does give us gets retargeted from its default (38
  # = SIGRTMIN+4 = systemd's hardcoded "start poweroff.target") to 34
  # (SIGRTMIN+0 = "start default.target"). Since default.target is
  # already the running system's target, that "start" is a safe
  # effective no-op for everything already active - except it also
  # (re)starts any of its own still-inactive Wants= dependencies, which is
  # the hook systemd.services.power-button-menu below rides on.
  #
  # Tradeoff, accepted deliberately: `nixos-rebuild switch` does this
  # same "reconcile default.target's Wants=" dance as part of normal
  # activation, so it *also* fires power-button-menu.service (opening
  # wlogout) on every switch. Harmless - it's just a menu, dismiss it
  # with Escape/the Cancel button - and simpler and safer than the
  # alternative tried first: retargeting to kexec.target instead, which
  # avoided the switch collision but turned out to not be inert - starting
  # kexec.target really does pull in systemd's actual shutdown chain
  # (Requires=shutdown.target through systemd-kexec.service), which
  # cannot be cleanly stripped via a NixOS unit override (empirically
  # verified: unlike ExecStart=, an empty-value reset does NOT clear
  # Requires=/Wants=/After= accumulated from the package's own vendored
  # unit file across a drop-in boundary - and masking the required
  # service instead fails the whole transaction, taking our own hooked
  # service down with it). That attempt genuinely kexec-rebooted the
  # machine once. Caused by this driver's design, not a fix for it -
  # reverted here in favor of the wlogout-on-every-switch tradeoff.
  boot.extraModprobeConfig = ''
    options tiny_power_button power_signal=34
  '';

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

  # wlogout's suspend/reboot/shutdown buttons call plain `systemctl
  # suspend/reboot/poweroff`, authorized by polkit's default
  # org.freedesktop.login1.* rules - which auto-allow those actions only
  # when the calling process belongs to the *active, local* session.
  # When wlogout is opened by power-button-menu above, `runuser -u
  # miky8745` opens a brand-new PAM/logind session just to host it - the
  # real niri session (started at login) stays the one marked active on
  # the seat, so that new session fails the active-session check and
  # polkit falls back to requiring interactive authentication, which
  # nothing here can satisfy. Result: wlogout's UI responds fine (that's
  # just GTK, no privilege involved) but Suspend/Restart/Shut Down are
  # silently denied - confirmed via `journalctl -u power-button-menu`:
  # "Call to Suspend failed: Access denied as the requested operation
  # requires interactive authentication." (lock/cancel aren't affected;
  # neither goes through logind/polkit.) Dropping the active-session
  # requirement for this one local user is reasonable here: the only way
  # this service's wlogout instance ever opens is a physical power-button
  # press, which already implies physical access.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.user == "miky8745" &&
          (action.id == "org.freedesktop.login1.suspend" ||
           action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
           action.id == "org.freedesktop.login1.reboot" ||
           action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
           action.id == "org.freedesktop.login1.power-off" ||
           action.id == "org.freedesktop.login1.power-off-multiple-sessions")) {
        return polkit.Result.YES;
      }
    });
  '';
}
