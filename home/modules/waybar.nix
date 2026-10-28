{
  programs.waybar = {
    enable = true;
    systemd.enable = true; # starts/stops with the graphical session

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 32;
        spacing = 4;

        modules-left = [ "niri/workspaces" "niri/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "tray" "pulseaudio" "network" "battery" ];

        "niri/workspaces" = {
          format = "{index}";
        };

        "niri/window" = {
          max-length = 60;
        };

        clock = {
          format = "{:%Y-%m-%d %H:%M}";
          tooltip-format = "{:%A, %d %B %Y}";
        };

        tray = {
          spacing = 8;
        };

        pulseaudio = {
          format = "{volume}% {icon}";
          format-muted = "muted";
          format-icons = {
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };

        network = {
          format-wifi = "{essid} ({signalStrength}%)";
          format-ethernet = "eth";
          format-disconnected = "disconnected";
        };

        battery = {
          format = "{capacity}% {icon}";
          format-icons = [ "" "" "" "" "" ];
          format-charging = "{capacity}% ";
        };
      };
    };

    style = ''
      * {
        font-family: "Cantarell", sans-serif;
        font-size: 13px;
      }

      window#waybar {
        background-color: rgba(30, 30, 30, 0.9);
        color: #e0e0e0;
      }

      #workspaces button {
        padding: 0 8px;
        color: #e0e0e0;
      }

      #workspaces button.focused {
        background-color: #7fc8ff;
        color: #1e1e1e;
      }

      #clock, #pulseaudio, #network, #battery, #tray {
        padding: 0 10px;
      }
    '';
  };
}
