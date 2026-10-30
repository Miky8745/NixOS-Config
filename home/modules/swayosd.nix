# On-screen display for volume/mic/brightness/keyboard-layout changes
# (the KDE/Windows-style popup that briefly shows what just changed and its
# new value). The actual key bindings that trigger it live in niri.nix -
# this module only runs the server that draws the popup and its look/position.
{ config, pkgs, ... }:

{
  xdg.configFile."swayosd/config.toml".text = ''
    [server]
    style = "${config.xdg.configHome}/swayosd/style.css"
    # Default top_margin (0.85) sits right at the bottom edge; this puts it
    # about 3/4 down the screen instead, per request. Always horizontally
    # centered - swayosd has no separate option for that axis.
    top_margin = 0.75
  '';

  xdg.configFile."swayosd/style.css".text = ''
    * {
      font-family: "JetBrainsMono Nerd Font Mono";
      font-weight: bold;
      font-size: 13px;
    }

    window#osd {
      border-radius: 10px;
      border: 1px solid #7fc8ff;
      background: #1e1e1eee;
    }

    window#osd #container {
      margin: 16px;
    }

    window#osd image,
    window#osd label {
      color: #e0e0e0;
    }

    window#osd progressbar:disabled,
    window#osd image:disabled {
      opacity: 0.5;
    }

    window#osd progressbar,
    window#osd segmentedprogress {
      min-height: 6px;
      border-radius: 999px;
      background: transparent;
      border: none;
    }

    window#osd trough,
    window#osd segment {
      min-height: inherit;
      border-radius: inherit;
      border: none;
      background: alpha(#e0e0e0, 0.3);
    }

    window#osd progress,
    window#osd segment.active {
      min-height: inherit;
      border-radius: inherit;
      border: none;
      background: #7fc8ff;
    }

    window#osd segment {
      margin-left: 8px;
    }

    window#osd segment:first-child {
      margin-left: 0;
    }
  '';

  # No home-manager module ships for this (unlike waybar/swaync/swayidle
  # above it in miky8745.nix), so it's wired up by hand - same shape as
  # those modules' own services, restarted on crash and tied to the
  # graphical session being up.
  systemd.user.services.swayosd-server = {
    Unit = {
      Description = "SwayOSD on-screen display server";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.swayosd}/bin/swayosd-server";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
