# Home Manager: your user-level config (dotfiles, user programs).
{ config, lib, pkgs, ... }:

{
  home.username = "miky8745";
  home.homeDirectory = "/home/miky8745";

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Miky8745";
        email = "mikulas.vanecek@gmail.com";
      };
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };

  # ---------- Zsh (generates ~/.zshrc and ~/.zshenv) ----------
  programs.zsh = {
    enable = true;
    defaultKeymap = "emacs"; # bindkey -e

    history = {
      path = "${config.home.homeDirectory}/.histfile"; # keep the old file, so restored history works
      size = 1000;
      save = 1000;
      share = true;
      ignoreDups = true;
    };
    setOptions = [ "INC_APPEND_HISTORY" ];

    # Replaces the default compinit line, so bash completions load too
    completionInit = ''
      autoload -Uz compinit && compinit
      autoload -Uz bashcompinit && bashcompinit
    '';

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ls = "ls --color=auto";
      ll = "ls -lh --color=auto";
      la = "ls -lha --color=auto";
    };

    initContent = lib.mkMerge [
      ''
        PROMPT='[%n@%m %c] %# '

        # NVM (prebuilt Node binaries run thanks to programs.nix-ld)
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
      ''
      (lib.mkAfter "fastfetch") # neofetch is unmaintained; fastfetch replaces it
    ];
  };

  # Replaces the `dircolors /etc/DIR_COLORS` line (that file doesn't exist on NixOS)
  programs.dircolors.enable = true;

  # ---------- niri (Wayland compositor) ----------
  # Full KDL reference: https://niri-wm.github.io/niri/Configuration:-Introduction
  # This starts from niri's own documented default config, trimmed of the
  # autostart line (waybar is started via its own systemd service below
  # instead) and extended with polkit + wallpaper-restore on login.
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us"
            }
            numlock
        }

        touchpad {
            tap
            natural-scroll
        }
    }

    // Run `niri msg outputs` once logged in to find your output name,
    // then uncomment and adjust a block like this if you want a fixed
    // resolution/scale/position instead of niri's automatic choice.
    // output "eDP-1" {
    //     mode "1920x1080@60.000"
    //     scale 1
    // }

    layout {
        gaps 16
        center-focused-column "never"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }

        default-column-width { proportion 0.5; }

        focus-ring {
            width 4
            active-color "#7fc8ff"
            inactive-color "#505050"
        }

        border {
            off
        }

        struts {
        }
    }

    // waybar, mako and swayidle are started as Home Manager systemd user
    // services (see programs.waybar / services.mako / services.swayidle),
    // not spawned here.
    spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
    spawn-sh-at-startup "${pkgs.waypaper}/bin/waypaper --restore"

    hotkey-overlay {
    }

    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

    animations {
    }

    // Nvidia's direct-scanout path has known corruption/flicker bugs on
    // proprietary drivers (same class of bug KWin works around on Nvidia);
    // this disables it so niri always composites instead.
    debug {
        disable-direct-scanout
    }

    // Open Vivaldi's picture-in-picture player as floating by default.
    // Chromium-based browsers can report a slightly different app-id; run
    // `niri msg windows` while the PiP player is open to confirm/adjust this.
    window-rule {
        match app-id=r#"vivaldi"# title="^Picture-in-Picture$"
        open-floating true
    }

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        Mod+T hotkey-overlay-title="Open a Terminal: alacritty" { spawn "alacritty"; }
        Mod+D hotkey-overlay-title="Run an Application: fuzzel" { spawn "fuzzel"; }
        Super+Alt+L hotkey-overlay-title="Lock the Screen: swaylock" { spawn "swaylock"; }

        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+ -l 1.0"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05-"; }
        XF86AudioMute        allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
        XF86AudioMicMute     allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }

        XF86AudioPlay  allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioPause allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioStop  allow-when-locked=true { spawn-sh "playerctl stop"; }
        XF86AudioPrev  allow-when-locked=true { spawn-sh "playerctl previous"; }
        XF86AudioNext  allow-when-locked=true { spawn-sh "playerctl next"; }

        XF86MonBrightnessUp   allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "+10%"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "10%-"; }


        Mod+O repeat=false { toggle-overview; }

        Mod+Q repeat=false { close-window; }

        Mod+Left  { focus-column-left; }
        Mod+Down  { focus-window-down; }
        Mod+Up    { focus-window-up; }
        Mod+Right { focus-column-right; }
        Mod+H     { focus-column-left; }
        Mod+J     { focus-window-down; }
        Mod+K     { focus-window-up; }
        Mod+L     { focus-column-right; }

        Mod+Ctrl+Left  { move-column-left; }
        Mod+Ctrl+Down  { move-window-down; }
        Mod+Ctrl+Up    { move-window-up; }
        Mod+Ctrl+Right { move-column-right; }
        Mod+Ctrl+H     { move-column-left; }
        Mod+Ctrl+J     { move-window-down; }
        Mod+Ctrl+K     { move-window-up; }
        Mod+Ctrl+L     { move-column-right; }

        Mod+Home { focus-column-first; }
        Mod+End  { focus-column-last; }

        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up   { focus-workspace-up; }
        Mod+U         { focus-workspace-down; }
        Mod+I         { focus-workspace-up; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        Mod+Ctrl+1 { move-column-to-workspace 1; }
        Mod+Ctrl+2 { move-column-to-workspace 2; }
        Mod+Ctrl+3 { move-column-to-workspace 3; }
        Mod+Ctrl+4 { move-column-to-workspace 4; }
        Mod+Ctrl+5 { move-column-to-workspace 5; }
        Mod+Ctrl+6 { move-column-to-workspace 6; }
        Mod+Ctrl+7 { move-column-to-workspace 7; }
        Mod+Ctrl+8 { move-column-to-workspace 8; }
        Mod+Ctrl+9 { move-column-to-workspace 9; }

        Mod+BracketLeft  { consume-or-expel-window-left; }
        Mod+BracketRight { consume-or-expel-window-right; }
        Mod+Comma  { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }

        Mod+R       { switch-preset-column-width; }
        Mod+Shift+R { switch-preset-column-width-back; }
        Mod+F       { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+M       { maximize-window-to-edges; }
        Mod+Ctrl+F  { expand-column-to-available-width; }
        Mod+C       { center-column; }

        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }

        Mod+V       { toggle-window-floating; }
        Mod+Shift+V { switch-focus-between-floating-and-tiling; }
        Mod+W       { toggle-column-tabbed-display; }

        Print      { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print  { screenshot-window; }

        Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

        Mod+Shift+E     { quit; }
        Ctrl+Alt+Delete { quit; }

        Mod+Shift+P { power-off-monitors; }
    }
  '';

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

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "alacritty";
        layer = "overlay";
      };
    };
  };

  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      border-radius = 6;
      background-color = "#1e1e1eee";
      text-color = "#e0e0e0";
      border-color = "#7fc8ff";
    };
  };

  # Idle handling that Plasma's powerdevil used to provide: lock the
  # session after inactivity, then turn the screens off, and always lock
  # before suspend.
  services.swayidle = {
    enable = true;
    timeouts = [
      { timeout = 300; command = "${pkgs.swaylock}/bin/swaylock -f"; }
      { timeout = 600; command = "${pkgs.niri}/bin/niri msg action power-off-monitors"; }
    ];
    events = {
      before-sleep = "${pkgs.swaylock}/bin/swaylock -f";
    };
  };

  programs.alacritty.enable = true;

  # ---------- Environment (loaded by every zsh via ~/.zshenv) ----------
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/Android/Sdk/cmdline-tools/latest/bin"
    "$HOME/Android/Sdk/platform-tools"
    "$HOME/.lmstudio/bin"
  ];

  home.sessionVariables = {
    ANDROID_HOME = "$HOME/Android/Sdk";
    ANDROID_SDK_ROOT = "$HOME/Android/Sdk";
    ANDROID_AVD_HOME = "$HOME/VMs/android-avd"; # emulator images on the no-CoW VMs subvolume
    ROS_DISTRO = "jazzy";

    # Haruna + DaVinci
    QT_QPA_PLATFORM = "xcb";
    QT_OPENGL = "desktop";

    # Disable VA-API, force NVIDIA GLX
    LIBVA_DRIVER_NAME = "dummy";
    VDPAU_DRIVER = "dummy";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  programs.home-manager.enable = true;

  # Same rule as system.stateVersion: set once, never change.
  home.stateVersion = "26.05";
}
