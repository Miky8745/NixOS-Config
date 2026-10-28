# Idle handling that Plasma's powerdevil used to provide: lock the session
# after inactivity, then turn the screens off, and always lock before suspend.
{ pkgs, ... }:

let
  # Guard against stacking a second lock surface if this fires while already
  # locked (e.g. idle timeout right after a manual lock). See niri.nix for
  # why QT_QPA_PLATFORM is forced here (environment.nix's xcb override
  # otherwise breaks Quickshell's session-lock protocol support).
  lockCmd = "${pkgs.procps}/bin/pgrep -f lock_shell.qml"
    + " || QT_QPA_PLATFORM=wayland qylock-lock";
in
{
  services.swayidle = {
    enable = true;
    timeouts = [
      { timeout = 300; command = lockCmd; }
      { timeout = 600; command = "${pkgs.niri}/bin/niri msg action power-off-monitors"; }
    ];
    events = {
      before-sleep = lockCmd;
    };
  };
}
