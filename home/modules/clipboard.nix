# Clipboard history: cliphist records everything copied, fuzzel (already
# used for app launching, see fuzzel.nix) picks an entry back out. The
# keybind that opens the picker lives in niri/binds.nix, not here - this
# module only runs the background watcher that builds the history.
{ pkgs, ... }:

{
  home.packages = [ pkgs.cliphist ];

  # Two watchers, not one: cliphist's own docs call out that a single
  # `wl-paste --watch cliphist store` misses image mime types, because
  # wl-paste --watch only ever reports one type per process. Text and
  # images need their own `--type` filter and their own process.
  systemd.user.services.cliphist-text = {
    Unit = {
      Description = "Clipboard history (text)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.cliphist-image = {
    Unit = {
      Description = "Clipboard history (images)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
