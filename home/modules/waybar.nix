# Waybar status bar.
#
# Settings/module choices are ours; the visual style (pill-shaped modules
# on a transparent bar) is adapted from Andrey0189's niri/Hyprland dotfiles:
# https://raw.githubusercontent.com/Andrey0189/nixos-config/refs/heads/main/home-manager/modules/wms/waybar.nix
# - module names swapped from hyprland/* to niri/* for this compositor, the
# battery/backlight/temperature modules dropped (desktop, no battery or
# managed backlight), every solid pill background given 80% opacity (alpha
# 0.8) per request instead of the source's fully opaque fills, and the
# source's floating top/bottom margin dropped: with a margin, the bar's
# layer-shell exclusive zone no longer lines up with where the pills are
# actually drawn, so niri's maximize-to-edges let windows fill that gap and
# visually poke through/around the bar. Anchored flush (no margin) keeps
# the exclusive zone and the visible bar the same rectangle, which is what
# keeps maximized windows from overlapping it.
{ pkgs, ... }:

{
  xdg.configFile."waybar/scripts/wttr.py" = {
    executable = true;
    text = ''
      #!/usr/bin/env python3
      import json
      import urllib.request

      # wttr.in weatherCode -> Nerd Font weather-icons glyph (codepoints verified
      # against nerd-fonts' glyphnames.json "weather-*" entries). Codes are
      # World Weather Online condition codes, which is what wttr.in's j1 format
      # reports in current_condition[0]["weatherCode"] / weather[n]["hourly"][n]
      # ["weatherCode"].
      ICONS = {
          113: "\ue30d",  # Sunny / Clear
          116: "\ue302",  # Partly cloudy
          119: "\ue312",  # Cloudy
          122: "\ue33d",  # Overcast
          143: "\ue303",  # Mist
          176: "\ue309",  # Patchy rain possible
          179: "\ue30a",  # Patchy snow possible
          182: "\ue3ad",  # Patchy sleet possible
          185: "\ue316",  # Patchy freezing drizzle possible
          200: "\ue30f",  # Thundery outbreaks possible
          227: "\ue31a",  # Blowing snow
          230: "\ue31a",  # Blizzard
          248: "\ue313",  # Fog
          260: "\ue313",  # Freezing fog
          263: "\ue30b",  # Patchy light drizzle
          266: "\ue31b",  # Light drizzle
          281: "\ue316",  # Freezing drizzle
          284: "\ue316",  # Heavy freezing drizzle
          293: "\ue309",  # Patchy light rain
          296: "\ue318",  # Light rain
          299: "\ue318",  # Moderate rain at times
          302: "\ue318",  # Moderate rain
          305: "\ue318",  # Heavy rain at times
          308: "\ue318",  # Heavy rain
          311: "\ue3ad",  # Light freezing rain
          314: "\ue3ad",  # Moderate/heavy freezing rain
          317: "\ue3ad",  # Light sleet
          320: "\ue3ad",  # Moderate/heavy sleet
          323: "\ue30a",  # Patchy light snow
          326: "\ue31a",  # Light snow
          329: "\ue31a",  # Patchy moderate snow
          332: "\ue31a",  # Moderate snow
          335: "\ue31a",  # Patchy heavy snow
          338: "\ue31a",  # Heavy snow
          350: "\ue314",  # Ice pellets
          353: "\ue319",  # Light rain shower
          356: "\ue319",  # Moderate/heavy rain shower
          359: "\ue319",  # Torrential rain shower
          362: "\ue3ad",  # Light sleet showers
          365: "\ue3ad",  # Moderate/heavy sleet showers
          368: "\ue31a",  # Light snow showers
          371: "\ue31a",  # Moderate/heavy snow showers
          374: "\ue314",  # Light showers of ice pellets
          377: "\ue314",  # Moderate/heavy showers of ice pellets
          386: "\ue31d",  # Patchy light rain with thunder
          389: "\ue31d",  # Moderate/heavy rain with thunder
          392: "\ue31d",  # Patchy light snow with thunder
          395: "\ue31d",  # Moderate/heavy snow with thunder
      }
      DEFAULT_ICON = "\ue33d"


      def fetch(url):
          req = urllib.request.Request(url, headers={"User-Agent": "curl/8.0"})
          with urllib.request.urlopen(req, timeout=10) as resp:
              return json.load(resp)


      def main():
          try:
              data = fetch("https://wttr.in/?format=j1")
              current = data["current_condition"][0]
              temp_c = current["temp_C"]
              code = int(current["weatherCode"])
              icon = ICONS.get(code, DEFAULT_ICON)

              lines = [f"Now: {current['weatherDesc'][0]['value']}, {temp_c}\u00b0C"]
              for day in data["weather"][:3]:
                  midday = day["hourly"][4]  # ~12:00 entry
                  desc = midday["weatherDesc"][0]["value"]
                  lines.append(
                      f"{day['date']}: {desc}, {day['mintempC']}\u2013{day['maxtempC']}\u00b0C"
                  )

              print(json.dumps({
                  "text": f"{icon} {temp_c}\u00b0C",
                  "tooltip": "\n".join(lines),
              }))
          except Exception as exc:
              print(json.dumps({
                  "text": f"{DEFAULT_ICON} ?",
                  "tooltip": f"weather unavailable: {exc}",
              }))


      if __name__ == "__main__":
          main()
    '';
  };

  programs.waybar = {
    enable = true;
    systemd.enable = true; # starts/stops with the graphical session

    settings = {
      mainBar = {
        layer = "top";
        position = "top";

        modules-left = [ "niri/workspaces" "niri/language" "niri/window" ];
        modules-center = [ "clock" "custom/weather" ];
        modules-right = [ "network" "custom/notification" "pulseaudio" "memory" "cpu" "tray" "custom/power" ];

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

        clock = {
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          format = "{:%a; %d %b, %I:%M %p}";
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
          format-wifi = "{essid} ({signalStrength}%)";
          format-ethernet = "eth";
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

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font Mono";
        font-weight: bold;
        font-size: 13px;
        min-height: 20px;
      }

      window#waybar {
        background: transparent;
      }

      window#waybar.hidden {
        opacity: 0.2;
      }

      #workspaces {
        margin-right: 8px;
        border-radius: 10px;
        transition: none;
        background: rgba(56, 60, 74, 0.8);
      }

      #workspaces button {
        transition: none;
        color: #7c818c;
        background: transparent;
        padding: 5px 10px;
        font-size: 16px;
      }

      #workspaces button:hover {
        transition: none;
        box-shadow: inherit;
        text-shadow: inherit;
        border-radius: inherit;
        color: #383c4a;
        background: rgba(124, 129, 140, 0.8);
      }

      #workspaces button.active {
        background: rgba(78, 82, 99, 0.8);
        color: white;
        border-radius: inherit;
      }

      #language {
        margin-right: 8px;
        padding: 0 16px;
        border-radius: 10px;
        transition: none;
        color: #ffffff;
        background: rgba(56, 60, 74, 0.8);
      }

      #window {
        padding: 0 16px;
        border-radius: 10px;
        color: #ffffff;
        background: rgba(56, 60, 74, 0.8);
      }

      #clock {
        padding: 0 16px;
        border-radius: 10px 0px 0px 10px;
        transition: none;
        color: #ffffff;
        background: rgba(56, 60, 74, 0.8);
      }

      #custom-weather {
        padding: 0 16px;
        border-radius: 0px 10px 10px 0px;
        transition: none;
        color: #ffffff;
        background: rgba(56, 60, 74, 0.8);
      }

      #network {
        margin-right: 8px;
        padding: 0 16px;
        border-radius: 10px;
        transition: none;
        color: #ffffff;
        background: rgba(56, 60, 74, 0.8);
      }

      #custom-notification {
        margin-right: 8px;
        padding: 0 16px;
        border-radius: 10px;
        transition: none;
        color: #ffffff;
        background: rgba(56, 60, 74, 0.8);
      }

      #pulseaudio {
        margin-right: 8px;
        padding: 0 16px;
        border-radius: 10px;
        transition: none;
        color: #ffffff;
        background: rgba(56, 60, 74, 0.8);
      }

      #pulseaudio.muted {
        background-color: rgba(144, 177, 177, 0.8);
        color: #2a5c45;
      }

      #memory {
        margin-right: 8px;
        padding: 0 16px;
        border-radius: 10px;
        transition: none;
        color: #ffffff;
        background: rgba(56, 60, 74, 0.8);
      }

      #cpu {
        margin-right: 8px;
        padding: 0 16px;
        border-radius: 10px;
        transition: none;
        color: #ffffff;
        background: rgba(56, 60, 74, 0.8);
      }

      #tray {
        margin-right: 8px;
        padding: 0 16px;
        border-radius: 10px;
        transition: none;
        color: #ffffff;
        background: rgba(56, 60, 74, 0.8);
      }

      #custom-power {
        padding: 0 18px;
        border-radius: 10px;
        transition: none;
        font-size: 16px;
        color: #1a1a1a;
        background: rgba(255, 108, 108, 0.8);
      }

      #custom-power:hover {
        background: rgba(255, 108, 108, 1);
      }
    '';
  };
}
