# Idle handling that Plasma's powerdevil used to provide: lock the session
# after inactivity, then turn the screens off, and always lock before suspend.
{ pkgs, ... }:

let
  # Guard against stacking a second lock surface if this fires while already
  # locked (e.g. idle timeout right after a manual lock). Must match by
  # process name (-x quickshell), not full command line (-f) - this
  # swayidle process's own argv contains the literal text "lock_shell.qml"
  # (it's quoting this very lockCmd as its own command argument), so `-f`
  # would match swayidle itself and always skip qylock-lock. See niri.nix
  # for the detailed story and why QT_QPA_PLATFORM is forced here
  # (environment.nix's xcb override otherwise breaks Quickshell's
  # session-lock protocol support).
  lockCmd = "${pkgs.procps}/bin/pgrep -x quickshell"
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
