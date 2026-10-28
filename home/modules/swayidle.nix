# Idle handling that Plasma's powerdevil used to provide: lock the session
# after inactivity, then turn the screens off, and always lock before suspend.
{ config, pkgs, ... }:

let
  # Guard against stacking a second lock surface if this fires while already
  # locked (e.g. idle timeout right after a manual lock).
  lockCmd = "${pkgs.procps}/bin/pgrep -f quickshell-lock/shell.qml"
    + " || ${pkgs.quickshell}/bin/quickshell -p ${config.home.homeDirectory}/.config/quickshell-lock/shell.qml";
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
