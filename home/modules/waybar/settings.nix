{ pkgs, ... }:

{
  programs.waybar.settings = {
    mainBar = {
      layer = "top";
      position = "top";

      modules-left = [ "niri/workspaces" "niri/language" "niri/window" ];
      modules-center = [ "custom/clock" "custom/weather" ];
      modules-right = [ "network" "custom/notification" "custom/media-pause" "custom/media-next" "pulseaudio" "memory" "cpu" "tray" "custom/power" ];

      "niri/workspaces" = {
        format = "{index}";
      };

      "niri/language" = {
        format = "{}";
        format-us = "US";
        format-cz = "CZ";
        min-length = 5;
        tooltip = false;
      };

      "niri/window" = {
        max-length = 60;
      };

      "custom/clock" = {
        format = "{}";
        tooltip = true;
        interval = 1;
        exec = "$HOME/.config/waybar/scripts/clock.py";
        return-type = "json";
      };

      "custom/weather" = {
        format = "{}";
        tooltip = true;
        interval = 1800;
        exec = "$HOME/.config/waybar/scripts/wttr.py";
        return-type = "json";
      };

      tray = {
        spacing = 8;
      };

      # Click opens/toggles the swaync history panel; right-click toggles
      # DND. swaync-client -swb emits waybar-ready JSON reflecting DND
      # state (see home/modules/swaync.nix for the daemon itself).
      "custom/notification" = {
        tooltip = false;
        format = "{icon}";
        format-icons = {
          notification = "";
          none = "";
          "dnd-notification" = "";
          "dnd-none" = "";
          "inhibited-notification" = "";
          "inhibited-none" = "";
          "dnd-inhibited-notification" = "";
          "dnd-inhibited-none" = "";
        };
        return-type = "json";
        exec-if = "which swaync-client";
        exec = "swaync-client -swb";
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        escape = true;
      };

      # Media playback controls - play/pause toggles, the other only
      # skips forward (no previous-track button). playerctl is on PATH
      # via environment.systemPackages (hosts/MikyNB/modules/packages.nix),
      # same as the XF86Audio* niri binds (home/modules/niri/binds.nix).
      "custom/media-pause" = {
        format = "";
        tooltip = true;
        tooltip-format = "Play/Pause";
        on-click = "playerctl play-pause";
      };

      "custom/media-next" = {
        format = "";
        tooltip = true;
        tooltip-format = "Next track";
        on-click = "playerctl next";
      };

      pulseaudio = {
        format = "{format_source} {icon} {volume}%";
        format-muted = "{format_source}  {volume}%";
        format-icons = {
          default = [ "" "" "" ];
        };
        # Mic (input source) status: shown whether it's muted or not.
        format-source = "";
        format-source-muted = "";
        on-click = "pavucontrol";
      };

      network = {
        #  = fa-wifi,  = fa-ethernet (both present in the
        # Nerd Font patch set used for format-wifi/format-ethernet above).
        format-wifi = "  {essid} ({signalStrength}%)";
        format-ethernet = "  eth";
        format-disconnected = "disconnected";
      };

      memory = {
        interval = 5;
        format = "{percentage}% ";
      };

      cpu = {
        interval = 5;
        format = "{usage}% ";
      };

      "custom/power" = {
        format = "";
        tooltip = false;
        # Opens a menu (lock/sleep/logout/restart/shutdown) instead of
        # immediately powering off - see home/modules/wlogout.nix. -b 3
        # forces 3 buttons per row (wlogout's own auto column count for
        # 5 buttons left a visibly empty 6th slot).
        on-click = "${pkgs.wlogout}/bin/wlogout -b 3";
      };
    };
  };
}
