# niri (Wayland compositor)
# Full KDL reference: https://niri-wm.github.io/niri/Configuration:-Introduction
# This starts from niri's own documented default config, trimmed of the
# autostart line (waybar is started via its own systemd service instead)
# and extended with polkit + wallpaper-restore on login.
#
# Keybinds live in binds.nix - this file is everything else (input, layout,
# autostart, window rules).
{ pkgs, ... }:

{
  imports = [ ./binds.nix ];

  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us,cz(qwerty)"
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

    // waybar, swaync and swayidle are started as Home Manager systemd user
    // services (see programs.waybar / services.swaync / services.swayidle),
    // not spawned here.
    spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
    // Pinned directly to the one image in ~/Background - simplest option,
    // and consistent with everything else here being declarative (edit this
    // file + rebuild to change it). waypaper (still installed) can pick a
    // different wallpaper interactively, but its own saved choice wouldn't
    // survive a rebuild unless this line is updated to match - ask if you'd
    // rather have waypaper's picker be the source of truth instead.
    spawn-sh-at-startup "${pkgs.swaybg}/bin/swaybg -i ~/Background/gargantua-black-5200x3250-9621.jpg -m fill"

    // Apps installed via environment.systemPackages in
    // hosts/MikyNB/configuration.nix - already on $PATH, so bare command
    // names (same as the alacritty/fuzzel binds above) are enough.
    spawn-at-startup "element-desktop"
    spawn-at-startup "discord"
    spawn-at-startup "vivaldi"
    // programs.kdeconnect.enable (configuration.nix) only installs the
    // package and opens the firewall ports - it starts no daemon. The
    // indicator binary is what actually gets kdeconnectd running too (DBus
    // activates it on demand), so spawning just the indicator is enough.
    spawn-at-startup "kdeconnect-indicator"
    // Tray icon for graphical Wi-Fi switching (click it in waybar's tray
    // module) - package is networkmanagerapplet, hosts/MikyNB/modules/packages.nix.
    spawn-at-startup "nm-applet"

    hotkey-overlay {
    }

    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

    animations {
    }

    // Ask clients to drop their own title bar/min-max-close buttons -
    // everything here is driven by hotkeys, so that chrome is just wasted
    // space. Most GTK/Qt apps honor this; terminals get it explicitly below.
    prefer-no-csd

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

    // Alacritty is semi-transparent (see home/modules/alacritty.nix). By
    // default niri draws the focus-ring as a solid filled rectangle behind
    // the window, so that fill bleeds through and makes the terminal look
    // opaque/tinted blue when focused. This stops the fill from being drawn
    // behind it, leaving just the thin ring border.
    window-rule {
        match app-id=r#"Alacritty"#
        draw-border-with-background false
    }

    // Super-slight rounding on every window. niri has no "is-maximized"
    // match predicate (open feature request upstream) to exclude maximized/
    // fullscreen windows specifically, but at this small a radius the
    // corner-clip on those is basically imperceptible, and `gaps` already
    // keeps normal tiled windows off the screen edge anyway.
    window-rule {
        geometry-corner-radius 4
        clip-to-geometry true
    }
  '';
}
