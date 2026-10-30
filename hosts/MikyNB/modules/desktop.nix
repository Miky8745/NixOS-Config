{ pkgs, ... }:

{
  # ---------- Desktop: niri (Wayland) ----------
  programs.niri.enable = true;
  # File manager is Dolphin (see packages below), so the portal's file-chooser
  # falls back to its GTK implementation instead of Nautilus.
  services.gvfs.enable = true; # trash/network places for the GTK file-chooser portal
  services.udisks2.enable = true; # removable-drive mounting (also used by Dolphin)

  # Greeter: regreet (GTK, via greetd+cage), running on Wayland.
  #
  # Previously this was SDDM's own Wayland greeter (weston --shell=kiosk,
  # forced to --renderer=pixman to dodge this Maxwell Nvidia GPU's
  # direct-scanout corruption, same workaround as niri's "debug
  # { disable-direct-scanout }" below). That combination left the greeter's
  # pointer completely dead - no visible cursor, no clicks, nothing, as if
  # no pointer device existed. A live weston input-device dump ruled out the
  # obvious theories: both the touchpad and the external USB mouse were
  # correctly picked up and associated with the output, and a direct
  # `drmGetCap(DRM_CAP_CURSOR_WIDTH/HEIGHT)` query showed this GPU's hardware
  # cursor plane supports up to 256x256 - well above the 72px cursor theme
  # size tried, ruling out a plane-size overflow too. weston's kiosk-shell
  # has no fallback path if hardware-cursor-plane compositing breaks, and
  # unlike wlroots-based compositors has no documented env-var workaround for
  # exactly this failure mode.
  #
  # cage (used here via programs.regreet.enable) is wlroots-based instead -
  # a far more common pairing for Wayland greeters, and wlroots has a long-
  # documented Nvidia hardware-cursor-plane bug with a known, safe fix
  # (WLR_NO_HARDWARE_CURSORS below forces software cursor compositing).
  programs.regreet = {
    enable = true;
    cursorTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    settings.background = {
      # Same image niri's swaybg uses as the desktop wallpaper (see
      # niri.nix) - copied into the repo (hosts/MikyNB/background.jpg) so
      # it's a store path, since the greeter's "greeter" system user can't
      # read into ~/Background (home is 0700, owned by miky8745).
      path = toString ../background.jpg;
      fit = "Cover"; # GTK4 ContentFit equivalent of swaybg's "-m fill"
    };
  };
  systemd.services.greetd.environment.WLR_NO_HARDWARE_CURSORS = "1";

  # Turns out this laptop's power button never reaches logind at all (see
  # power-button.nix's extraModprobeConfig comment for the real mechanism) -
  # this setting was a first, insufficient attempt at fixing it. Left in
  # place as harmless defensive config in case any *other* path ever does
  # route a power keypress through logind.
  services.logind.settings.Login.HandlePowerKey = "ignore";

  # Lid-close was briefly forced to "poweroff" while suspend appeared to
  # hang unrecoverably - see wlogout.nix's Sleep-button comment, same root
  # cause, now fixed. Back to systemd's own default ("suspend") rather
  # than an explicit override.

  # Chromium-based apps (Discord, Vivaldi - see niri.nix) create their own
  # "app-<name>-<pid>.scope" cgroup on launch (Chromium's own systemd-oomd
  # integration, not something niri or this config spawns), and Discord's
  # doesn't react to SIGTERM. On logout/reboot that leaves the user manager
  # waiting out the full default 90s TimeoutStopSec before SIGKILLing it
  # (confirmed via journalctl: "app-discord-*.scope: Stopping timed out.
  # Killing."), which is the ~1min19s/1min39s stall seen on roughly every
  # 3rd reboot - whichever ones happen to catch Discord still running.
  # Since that scope's name is dynamic (PID-based) and not ours to target
  # with a drop-in, lower the user manager's default stop timeout instead.
  systemd.user.extraConfig = "DefaultTimeoutStopSec=10s";

  programs.kdeconnect.enable = true; # also opens its firewall ports

  # Lock screen (in-session only, not the greeter above): qylock
  # (github:Darkkal44/qylock), "enfield" theme. Its Quickshell lock
  # authenticates through PAM's default "login" service (not a dedicated
  # one), and runs third-party QML - a deliberate trust tradeoff over the
  # previous hand-rolled pam_unix-only setup, made knowingly rather than by
  # default.
  programs.qylock = {
    enable = true;
    theme = "enfield";
    sddm.enable = false; # no SDDM anymore - see the greeter comment above
  };
}
