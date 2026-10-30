# Notification daemon with a history panel and a DND toggle (mako had
# neither). Panel is opened/toggled from the waybar bell icon - see
# "custom/notification" in home/modules/waybar.nix.
{
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-layer = "top";
      layer-shell = true;
      control-center-margin-top = 8;
      control-center-margin-bottom = 8;
      control-center-margin-right = 8;
      control-center-margin-left = 8;
      notification-icon-size = 48;
      timeout = 5;
      timeout-low = 5;
      timeout-critical = 0;
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font Mono";
        font-weight: bold;
        font-size: 13px;
      }

      .notification-row, .control-center-list-placeholder {
        background: transparent;
      }

      .notification-background, .control-center {
        background: #1e1e1eee;
        color: #e0e0e0;
      }

      .notification {
        border-radius: 6px;
        border: 1px solid #7fc8ff;
        background: #1e1e1eee;
        color: #e0e0e0;
        margin: 6px 12px;
        padding: 0;
      }

      .control-center {
        border-radius: 6px;
        border: 1px solid #7fc8ff;
      }

      .widget-title, .widget-dnd {
        background: transparent;
        color: #e0e0e0;
      }

      .widget-title button, .widget-dnd > switch {
        border-radius: 6px;
      }
    '';
  };
}
